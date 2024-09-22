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
<div id="settingsEditorPopup" style="display:none;left:0px;top:0px;" class="windowDiv">
  <table cellpadding="0" cellspacing="0"><tr><td>
    <table width="100%">
      <tr>
        <td>
          <tag:img png="plugin_edit" title="viewEdit.settings.editor" style="display:inline;"/>
          <span class="copyTitle" id="settingsComponentName"></span>
        </td>
        <td align="right">
          <tag:img png="save" onclick="settingsEditor.save()" title="common.save" style="display:inline;"/>&nbsp;
          <tag:img png="cross" onclick="settingsEditor.close()" title="common.close" style="display:inline;"/>
        </td>
      </tr>
    </table>
    <table>
      <tr>
        <td class="formLabelRequired"><fmt:message key="viewEdit.settings.point"/></td>
        <td class="formField"><select id="settingsPointList" onchange="settingsEditor.pointSelectChanged()"></select></td>
      </tr>
      <tr>
        <td class="formLabel"><fmt:message key="viewEdit.settings.nameOverride"/></td>
        <td class="formField"><input id="settingsPointName" type="text"/></td>
      </tr>
      <tr>
        <td class="formLabel"><fmt:message key="viewEdit.settings.permissionOverride"/></td>
        <td class="formField"><input id="settingsPermissionOverride" type="checkbox"/></td>
      </tr>
      <tr>
        <td class="formLabel"><fmt:message key="viewEdit.anonymous"/></td>
        <td class="formField"><select id="settingsAnonymousAccess"/></td>
      </tr>
      <tr>
        <td class="formLabel"><fmt:message key="viewEdit.settings.background"/></td>
        <td class="formField"><input id="settingsBkgdColor" type="text"/></td>
      </tr>
      <tr>
        <td class="formLabel"><fmt:message key="viewEdit.settings.displayControls"/></td>
        <td class="formField"><input id="settingsControls" type="checkbox"/></td>
      </tr>
    </table>
  </td></tr></table>

  <script type="text/javascript">
    // Script requires
    //  - Drag and Drop library for locating objects and positioning the window.
    //  - DWR utils for using byId() prototype.
    //  - common.js
    function SettingsEditor() {
        this.componentId = null;
        this.pointList = [];

        this.open = function(compId) {
            settingsEditor.componentId = compId;

            ViewDwr.getViewComponent(compId, function(comp) {
                $set("settingsComponentName", comp.displayName);

                // Update the point list
                settingsEditor.updatePointList(comp.supportedDataTypes);

                // Update the data in the form.
                $set("settingsPointList", comp.dataPointId);
                settingsEditor.pointSelectChanged();
                $set("settingsPointName", comp.nameOverride);
                $set("settingsPermissionOverride", comp.permissionOverride);
                $set("settingsBkgdColor", comp.bkgdColorOverride);
                $set("settingsControls", comp.displayControls);
                $set("settingsAnonymousAccess", comp.anonymousAccess);

                show("settingsEditorPopup");
            });

            positionEditor(compId, "settingsEditorPopup");
        };

        this.close = function() {
            hide("settingsEditorPopup");
            hideContextualMessages("settingsEditorPopup");
        };

        this.save = function() {
            hideContextualMessages("settingsEditorPopup");
            ViewDwr.setPointComponentSettings(settingsEditor.componentId, $get("settingsPointList"),
                    $get("settingsPointName"), $get("settingsPermissionOverride"), $get("settingsBkgdColor"),
                    $get("settingsControls"), $get("settingsAnonymousAccess"), function(response) {
                if (response.hasMessages) {
                    showDwrMessages(response.messages);
                }
                else {
                    settingsEditor.close();
                    MiscDwr.notifyLongPoll(mango.longPoll.pollSessionId);
                }
            });
        };

        this.setPointList = function(pointList) {
            settingsEditor.pointList = pointList;
        };

        this.pointSelectChanged = function() {
            var point = getElement(settingsEditor.pointList, $get("settingsPointList"));
            if(!point){
                $set("settingsPermissionOverride", false);
                byId("settingsPermissionOverride").disabled = true;
                $set("settingsAnonymousAccess", <%= Integer.toString(ShareUser.ACCESS_NONE) %>);
                byId("settingsAnonymousAccess").disabled = true;
            }else{
                var select = byId("settingsAnonymousAccess");
                select.innerHTML="";

                if(!point.settable)
                    var data = [ { value:<%= Integer.toString(ShareUser.ACCESS_NONE) %>, text:"<fmt:message key='common.access.none'/>" },
                                 { value:<%= Integer.toString(ShareUser.ACCESS_READ) %>, text:"<fmt:message key='common.access.read'/>" } ];

                else
                    var data = [ { value:<%= Integer.toString(ShareUser.ACCESS_NONE) %>, text:"<fmt:message key='common.access.none'/>" },
                                 { value:<%= Integer.toString(ShareUser.ACCESS_READ) %>, text:"<fmt:message key='common.access.read'/>" },
                                 { value:<%= Integer.toString(ShareUser.ACCESS_SET) %>, text:"<fmt:message key='common.access.set'/>" }];

                dwr.util.addOptions("settingsAnonymousAccess", data, "value", "text");
                byId("settingsPermissionOverride").disabled = false;
                byId("settingsAnonymousAccess").disabled = false;
            }
        };

        this.updatePointList = function(dataTypes) {
            dwr.util.removeAllOptions("settingsPointList");
            var sel = byId("settingsPointList");
            sel.options[0] = new Option("", 0);

            for (var i=0; i<settingsEditor.pointList.length; i++) {
                if (contains(dataTypes, settingsEditor.pointList[i].dataType))
                    sel.options[sel.options.length] = new Option(settingsEditor.pointList[i].name,
                            settingsEditor.pointList[i].id);
            }
        };
    }
    var settingsEditor = new SettingsEditor();
  </script>
</div>