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
<%@page import="com.serotonin.mango.view.component.SimpleCompoundComponent"%>
<div id="compoundEditorPopup" style="display:none;left:0px;top:0px;" class="windowDiv">
  <table cellpadding="0" cellspacing="0"><tr><td>
    <table width="100%">
      <tr>
        <td>
          <tag:img png="plugin_edit" title="viewEdit.compound.editor" style="display:inline;"/>
          <span class="copyTitle" id="compoundComponentName"></span>
        </td>
        <td align="right">
          <tag:img png="save" onclick="compoundEditor.save()" title="common.save" style="display:inline;"/>&nbsp;
          <tag:img png="cross" onclick="compoundEditor.close()" title="common.close" style="display:inline;"/>
        </td>
      </tr>
    </table>
    <table>
      <tr>
        <td class="formLabelRequired"><fmt:message key="viewEdit.compound.name"/></td>
        <td class="formField"><input id="compoundName" type="text"/></td>
      </tr>
      <tr>
        <td class="formLabel"><fmt:message key="viewEdit.settings.permissionOverride"/></td>
        <td class="formField"><input id="compoundPermissionOverride" type="checkbox"/></td>
      </tr>
      <tr>
        <td class="formLabel"><fmt:message key="viewEdit.anonymous"/></td>
        <td class="formField"><select id="compoundAnonymousAccess"/></td>
      </tr>
      <tbody id="simpleCompoundAttrs">
        <tr>
          <td class="formLabel"><fmt:message key="viewEdit.compound.backgroundColour"/></td>
          <td class="formField"><input id="compoundBackgroundColour" type="text"/></td>
        </tr>
      </tbody>
      <tbody id="imageChartAttrs">
        <tr>
          <td class="formLabelRequired"><fmt:message key="viewEdit.compound.width"/></td>
          <td class="formField"><input id="imageChartWidth" type="text"/></td>
        </tr>
        <tr>
          <td class="formLabelRequired"><fmt:message key="viewEdit.compound.height"/></td>
          <td class="formField"><input id="imageChartHeight" type="text"/></td>
        </tr>
        <tr>
          <td class="formLabelRequired"><fmt:message key="viewEdit.compound.duration"/></td>
          <td class="formField">
            <input type="text" id="imageChartDurationPeriods" class="formShort"/>
            <select id="imageChartDurationType">
              <tag:timePeriodOptions sst="false" s="true" min="true" h="true" d="true" w="true" mon="true" y="true"/>
            </select>
          </td>
        </tr>
      </tbody>
      <tbody id="pointLists">
      </tbody>
    </table>
  </td></tr></table>

  <script type="text/javascript">
    function CompoundEditor() {
        this.component = null;
        this.pointList = [];
        this.myPointChildren = new Array();
        this.open = function(compId) {
            ViewDwr.getViewComponent(compId, function(comp) {
                compoundEditor.component = comp;
                $set("compoundComponentName", comp.displayName);

                // Update the point lists
                compoundEditor.updatePointLists(compoundEditor.getPointChildren());

                // Update the data in the form.
                $set("compoundName", comp.name);
                $set("compoundPermissionOverride", comp.permissionOverride);

                if (comp.defName == "simpleCompound") {
                    $set("compoundBackgroundColour", comp.backgroundColour);
                    show("simpleCompoundAttrs");
                    var data = [ { value:<%= Integer.toString(ShareUser.ACCESS_NONE) %>, text:"<fmt:message key='common.access.none'/>" },
                                 { value:<%= Integer.toString(ShareUser.ACCESS_READ) %>, text:"<fmt:message key='common.access.read'/>" },
                                 { value:<%= Integer.toString(ShareUser.ACCESS_SET) %>, text:"<fmt:message key='common.access.set'/>" }];
                }
                else{
                    hide("simpleCompoundAttrs");
                    var data = [ { value:<%= Integer.toString(ShareUser.ACCESS_NONE) %>, text:"<fmt:message key='common.access.none'/>" },
                                 { value:<%= Integer.toString(ShareUser.ACCESS_READ) %>, text:"<fmt:message key='common.access.read'/>" }];
                }
                if (comp.defName == "imageChart") {
                    $set("imageChartWidth", comp.width);
                    $set("imageChartHeight", comp.height);
                    $set("imageChartDurationType", comp.durationType);
                    $set("imageChartDurationPeriods", comp.durationPeriods);
                    show("imageChartAttrs");
                }
                else
                    hide("imageChartAttrs");

                var select = byId("compoundAnonymousAccess");
                select.innerHTML="";
                dwr.util.addOptions("compoundAnonymousAccess", data, "value", "text");
                $set("compoundAnonymousAccess", comp.anonymousAccess);
                show("compoundEditorPopup");
            });

            positionEditor(compId, "compoundEditorPopup");
        };

        this.close = function() {
            hide("compoundEditorPopup");
            hideContextualMessages("compoundEditorPopup");
        };


        this.save = function() {
            hideContextualMessages("compoundEditorPopup");

            // Gather the point settings
            var childPointIds = new Array();
            var sel;

            for (var i=0; i<myPointChildren.length; i++)
                childPointIds.push({key: myPointChildren[i].id, value: $get("compoundPointSelect"+ myPointChildren[i].id)});

            if (compoundEditor.component.defName == "simpleCompound")
                ViewDwr.saveSimpleCompoundComponent(compoundEditor.component.id, $get("compoundName"),
                        $get("compoundBackgroundColour"), childPointIds, $get("compoundPermissionOverride"),
                        $get("compoundAnonymousAccess"), compoundEditor.saveCB);
            else if (compoundEditor.component.defName == "imageChart")
                ViewDwr.saveImageChartComponent(compoundEditor.component.id, $get("compoundName"),
                        $get("imageChartWidth"), $get("imageChartHeight"), $get("imageChartDurationType"),
                        $get("imageChartDurationPeriods"), childPointIds, $get("compoundPermissionOverride"),
                        $get("compoundAnonymousAccess"), compoundEditor.saveCB);
            else
                ViewDwr.saveCompoundComponent(compoundEditor.component.id, $get("compoundName"), childPointIds,
                        $get("compoundPermissionOverride"), $get("compoundAnonymousAccess"), compoundEditor.saveCB);

        };

        this.saveCB = function(response) {
            if (response.hasMessages)
                showDwrMessages(response.messages);
            else {
                if (compoundEditor.component.defName == "simpleCompound")
                    byId("c"+ compoundEditor.component.id +"Info").style.background = $get("compoundBackgroundColour");

                MiscDwr.notifyLongPoll(mango.longPoll.pollSessionId);
                compoundEditor.close();
            }
        };

        this.setPointList = function(pointList) {
            compoundEditor.pointList = pointList;
        };

        this.updatePointLists = function(pointChildren) {

            // Create the select controls
            dwr.util.removeAllRows("pointLists");
            dwr.util.addRows("pointLists", pointChildren,
                [
                    function(data) { return data.description; },
                    function(data) { return '<select id="compoundPointSelect'+ data.id +'" onchange="compoundEditor.selectChange(\'' + data.id + '\')"></select>'; },
                    function(data) {
                        if(data != pointChildren[0] && data == pointChildren[pointChildren.length-1] )
                            return '<img src="images/bullet_delete.png" title="<fmt:message key="common.delete"/>" id="deleteImg'
                                + data.id +'" '+'class="ptr" onclick="compoundEditor.deleteChildComponent(\'' + data.id + '\')"/>';

                        return null;
                    },
                    function(data) {
                        if(data == pointChildren[pointChildren.length-1] )
                        return '<img src="images/bullet_add.png" title="<fmt:message key="common.add"/>" id="pointAdd" '
                            + 'class="ptr" onclick="compoundEditor.addChildComponent()"/>';

                        return null;
                    }
                ],
                {
                    cellCreator: function(options) {
                        var td = document.createElement("td");
                        if (options.cellNum == 0)
                            td.className = "formLabelRequired";
                        else if (options.cellNum == 1)
                            td.className = "formField";
                        return td;
                    }
                }
            );

            // Add options to the controls.
            var sel, p;
            for (var i=0; i<pointChildren.length; i++) {
                sel = byId("compoundPointSelect"+ pointChildren[i].id);
                sel.options[0] = new Option("", 0);
                for (p=0; p<compoundEditor.pointList.length; p++) {
                    if (contains(pointChildren[i].dataTypes, compoundEditor.pointList[p].dataType))
                        sel.options[sel.options.length] = new Option(settingsEditor.pointList[p].name,
                                settingsEditor.pointList[p].id);
                }

                // Set the control default value.
                $set(sel, pointChildren[i].pointComponent.dataPointId);
            }
        };

        this.getPointChildren = function() {
            var pointChildren = new Array();
            for (var i=0; i<compoundEditor.component.childComponents.length; i++) {
                pointChildren.push(compoundEditor.component.childComponents[i]);
            }
            myPointChildren = pointChildren;
            return pointChildren;
        };

        this.addChildComponent = function (){

            ViewDwr.createChildComponent(compoundEditor.component.id, function(data){
                myPointChildren.push(data);
                compoundEditor.updatePointLists(myPointChildren);
            });
        };

        this.deleteChildComponent = function(id){

            var i;
            for (var i=0; i<myPointChildren.length; i++){
                if (myPointChildren[i].id == id){
                    myPointChildren.splice(i,1);
                    break;
                }
            }
            ViewDwr.removeChildComponent(compoundEditor.component.id, id);
            compoundEditor.updatePointLists(myPointChildren);
        };

        this.selectChange = function (id){
            for (var i=0; i<myPointChildren.length; i++){
                if (myPointChildren[i].id == id){
                    myPointChildren[i].pointComponent.dataPointId = $get("compoundPointSelect"+ myPointChildren[i].id);
                    break;
                }
            }
        }

        this.refresh = function (){

            var pointChildren = compoundEditor.component.childComponents;

            if(myPointChildren.length > pointChildren.length){              //New points
                for(i=0;i<myPointChildren.length - pointChildren.length;i++){

                    childContent = byId("compoundChildTemplate").cloneNode(true);
                    configureComponentContent(childContent, myPointChildren[pointChildren.length+i].pointComponent,
                        byId("c"+ compoundEditor.component.id +"Content"), false);

                    childContent.id = "c"+ myPointChildren[pointChildren.length+i].pointComponent.id;
                    childContent.viewComponentId = myPointChildren[pointChildren.length+i].pointComponent.id;
                    addPDnD(childContent,compoundEditor.component.id, myPointChildren[pointChildren.length+i].id);
                }
            }else if(pointChildren.length > myPointChildren.length){        //Points deleted
                for(i=0;i<pointChildren.length - myPointChildren.length;i++){
                    var div = byId("c"+ pointChildren[myPointChildren.length+i].pointComponent.id);
                    var div1 = byId("c"+ compoundEditor.component.id + "Content");
                    div.dragSource.unregister();
                    div1.removeChild(div);

                }
            }
        }
    }
    var compoundEditor = new CompoundEditor();
  </script>
</div>