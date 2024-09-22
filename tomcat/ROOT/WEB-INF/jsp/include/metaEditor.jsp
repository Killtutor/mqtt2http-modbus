<%--
    Mango - Open Source M2M - http://mango.serotoninsoftware.com
    Copyright (C) 2006-2011 Serotonin Software Technologies Inc.
    @author Matthew Lohbihler

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see http://www.gnu.org/licenses/.
--%>
<%@ include file="/WEB-INF/jsp/include/tech.jsp" %>
<div id="metaEditorPopup" style="display:none;left:0px;top:0px;" class="windowDiv">
  <table cellpadding="0" cellspacing="0"><tr><td>
    <table width="100%">
      <tr>
        <td>
          <tag:img png="plugin_edit" title="viewEdit.meta.editor" style="display:inline;"/>
          <span class="copyTitle" id="metaComponentName"></span>
        </td>
        <td align="right">
          <tag:img png="save" onclick="metaEditor.save()" title="common.save" style="display:inline;"/>&nbsp;
          <tag:img png="cross" onclick="metaEditor.close()" title="common.close" style="display:inline;"/>
        </td>
      </tr>
    </table>

    <div>
      <table>
        <tr>
          <td class="formLabel"><fmt:message key="viewEdit.settings.permissionOverride"/></td>
          <td class="formField"><input id="metaPermissionOverride" type="checkbox"/></td>
        </tr>
        <tr>
          <td class="formLabel"><fmt:message key="viewEdit.anonymous"/></td>
          <td class="formField">
            <select id="metaAnonymousAccess">
              <option value="<c:out value="<%= Integer.toString(ShareUser.ACCESS_NONE) %>"/>"><fmt:message key="common.access.none"/></option>
              <option value="<c:out value="<%= Integer.toString(ShareUser.ACCESS_READ) %>"/>"><fmt:message key="common.access.read"/></option>
            </select>
          </td>
        </tr>
      </table>
    </div>
    <div style="margin-top:10px;" class="borderWindowDiv">
      <table>
        <tr>
          <td class="formLabelRequired"><fmt:message key="dsEdit.meta.scriptContext"/></td>
          <td class="formField"><select id="metaPointList"></select></td>
          <td><tag:img png="add" onclick="metaEditor.addPointToContext();" title="common.add"/></td>
        </tr>
      </table>
      <table>
        <tbody id="metaContextTableEmpty" style="display:none;">
          <tr><th colspan="4"><fmt:message key="dsEdit.meta.noPoints"/></th></tr>
        </tbody>
        <tbody id="metaContextTableHeaders" style="display:none;">
          <tr class="smRowHeader">
            <td><fmt:message key="dsEdit.meta.pointName"/></td>
            <td><fmt:message key="dsEdit.pointDataType"/></td>
            <td><fmt:message key="dsEdit.meta.var"/></td>
            <td></td>
          </tr>
        </tbody>
        <tbody id="metaContextTable"></tbody>
      </table>
      <table id="metaContextMsg"></table>
    </div>
    <div style="margin-top:10px; margin-bottom:5px;">
      <span class="formLabelRequired"><fmt:message key="dsEdit.meta.script"/></span><br/>
      <span class="formField"><textarea id="metaScript" rows="10" cols="50"></textarea></span>
    </div>
  </td></tr></table>

  <script type="text/javascript">
    // Script requires
    //  - Drag and Drop library for locating objects and positioning the window.
    //  - DWR utils for using byId() prototype.
    //  - common.js
    function MetaEditor() {
        this.componentId = null;
        this.defName = null;
        this.pointList = [];
        this.contextArray = new Array();
        this.selectedPoint=0;

        this.open = function(compId) {
            metaEditor.componentId = compId;

            // Set the renderers for the data type of this point view.
            ViewDwr.getViewComponent(compId, metaEditor.setViewComponent);
            positionEditor(compId, "metaEditorPopup");
        };

        this.setViewComponent = function(comp) {
            metaEditor.defName = comp.defName;
            $set("metaComponentName", comp.displayName);

            // Update the data in the form.
            $set("metaScript", comp.script);
            $set("metaPermissionOverride", comp.permissionOverride);
            $set("metaAnonymousAccess", comp.anonymousAccess);
            metaEditor.contextArray.length = 0;
            for (var i=0; i<comp.context.length; i++)
                metaEditor.addToContextArray(comp.context[i].key, comp.context[i].value);
            metaEditor.writeContextArray();

            show("metaEditorPopup");
        };

        this.close = function() {
            hide("metaEditorPopup");
            hideContextualMessages("metaEditorPopup");
        };

        this.save = function() {
            hideContextualMessages("metaEditorPopup");

            ViewDwr.saveMetaComponent(metaEditor.componentId, $get("metaScript"), metaEditor.createContextArray(),
                    $get("metaPermissionOverride"), $get("metaAnonymousAccess"), metaEditor.saveCB);
        };

        this.saveCB = function(response) {
            if (response.hasMessages)
                showDwrMessages(response.messages);
            else {
                metaEditor.close();
                MiscDwr.notifyLongPoll(mango.longPoll.pollSessionId);
            }
        };

        this.setPointList = function(pointList) {
            metaEditor.pointList = pointList;
        };

        this.updatePointList = function() {
            dwr.util.removeAllOptions("metaPointList");
            var availPoints = new Array();

            for (var i=0; i<metaEditor.pointList.length; i++) {
                var found = false;
                for (var j=0; j<metaEditor.contextArray.length; j++) {
                    if (metaEditor.contextArray[j].pointId == metaEditor.pointList[i].id) {
                        found = true;
                        break;
                    }
                }
                if (!found)
                    availPoints[availPoints.length] = metaEditor.pointList[i];
            }
            dwr.util.addOptions("metaPointList", availPoints, "id", "name");

            var sel = byId("metaPointList");
            if(metaEditor.selectedPoint >= sel.length)
                sel.selectedIndex = sel.length-1;
            else
                sel.selectedIndex = metaEditor.selectedPoint;
        };

        this.writeContextArray = function() {
            dwr.util.removeAllRows("metaContextTable");
            if (metaEditor.contextArray.length == 0) {
                show(byId("metaContextTableEmpty"));
                hide(byId("metaContextTableHeaders"));
            }
            else {
                hide(byId("metaContextTableEmpty"));
                show(byId("metaContextTableHeaders"));
                dwr.util.addRows("metaContextTable", metaEditor.contextArray,
                    [
                        function(data) { return data.pointName; },
                        function(data) { return data.pointType; },
                        function(data) {
                        return "<input type='text' value='"+ data.scriptVarName +"' class='formShort' onblur='metaEditor.updateMetaVarName("+ data.pointId +", this.value)'/>";},
                        function(data) {
                            return "<img src='images/bullet_delete.png' class='ptr' onclick='metaEditor.removeFromContextArray("+ data.pointId +")'/>";
                        }
                    ],
                        {
                            rowCreator:function(options) {
                                var tr = document.createElement("tr");
                                tr.className = "smRow"+ (options.rowIndex % 2 == 0 ? "" : "Alt");
                                return tr;
                            }
                        }
                    );
            }
            metaEditor.updatePointList();
        };

        this.createContextArray = function() {
            var context = new Array();
            for (var i=0; i<metaEditor.contextArray.length; i++) {
                context[context.length] = {
                    key : metaEditor.contextArray[i].pointId,
                    value : metaEditor.contextArray[i].scriptVarName
                };
            }
            return context;
        };

        this.addToContextArray = function(pointId, scriptVarName) {
            var data = getElement(metaEditor.pointList, pointId);
            if (data) {
                // Missing names imply that the point was deleted, so ignore.
                metaEditor.contextArray[metaEditor.contextArray.length] = {
                    pointId : pointId,
                    pointName : data.name,
                    pointType : data.dataTypeMessage,
                    scriptVarName : scriptVarName
                };
            }
        };

        this.updateMetaVarName = function(pointId, scriptVarName) {
            for (var i=metaEditor.contextArray.length-1; i>=0; i--) {
                if (metaEditor.contextArray[i].pointId == pointId)
                    metaEditor.contextArray[i].scriptVarName = scriptVarName;
            }
        };

        this.removeFromContextArray = function(pointId) {
            for (var i=metaEditor.contextArray.length-1; i>=0; i--) {
                if (metaEditor.contextArray[i].pointId == pointId)
                    metaEditor.contextArray.splice(i, 1);
            }
            metaEditor.writeContextArray();
        };

        this.addPointToContext = function() {
            var pointId = $get("metaPointList");
            metaEditor.selectedPoint = byId("metaPointList").selectedIndex;
            metaEditor.addToContextArray(pointId, "p"+ pointId);
            metaEditor.writeContextArray();

        };
    }
    var metaEditor = new MetaEditor();
  </script>
</div>