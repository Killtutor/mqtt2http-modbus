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
<%@page import="com.serotonin.mango.Common"%>
<c:set var="NEW_ID"><%= Common.NEW_ID %></c:set>

<tag:page dwr="CompoundEventsDwr" onload="init">
<jsp:attribute name="subtitle">
  <fmt:message key="header.compoundEvents"/>
</jsp:attribute>
<jsp:body>
  <script type="text/javascript">
    require([
        "dojo/store/Memory", "dojo/store/Observable", "dijit/tree/ObjectStoreModel", "dijit/Tree", "dojo/_base/declare", "dojo/domReady!"
    ], function(Memory, Observable, ObjectStoreModel, Tree, declare){
        // Store
        pointHierarchyStore = new Memory({
            data: [
                { id: "root", name:'root', isFolder:true},
                { id: "dpRoot", name:'<fmt:message key="compoundDetectors.pointEventDetector"/>', isFolder:true, parent:'root'},
                { id: "seRoot", name:'<fmt:message key="scheduledEvents.ses"/>', isFolder:true, parent:'root'}
            ],
            getChildren: function(parentItem){
                return this.query({parent: parentItem.id});
            }
        });
        pointHierarchyStore = new Observable(pointHierarchyStore);

        // Model
        var pointHierarchyModel = new ObjectStoreModel({
            store: pointHierarchyStore,
            query: {id: "root"},
            mayHaveChildren: function(item){
                return item.isFolder;
            }
        });

        // Tree node
        var MyTreeNode = declare(Tree._TreeNode, {
            _setLabelAttr: {node: "labelNode", type: "innerHTML"}
        });

        // Tree
        var tree = new Tree({
            model: pointHierarchyModel,
            showRoot: false,
            autoExpand: false,
            getIconClass: function(item, opened){
                return null;
            },
            _createTreeNode: function(args){
                return new MyTreeNode(args);
            },
            onClick: function(item, node, evt){
                if(!item.isFolder)
                    insertText(item.key);
            }
        });
        tree.placeAt(byId("treeDiv"));
        tree.startup();
    });

    function init() {
        CompoundEventsDwr.getInitData(function(data) {
            // List the compound events.
            for (var i=0; i<data.compoundEvents.length; i++) {
                appendCompoundEvent(data.compoundEvents[i].id);
                updateCompoundEvent(data.compoundEvents[i]);
            }

            // Create the tree of event detectors
            var i, j;
            var dp, et;
            var dpNode, etNode;

            for (i=0; i<data.dataPoints.length; i++) {
                dp = data.dataPoints[i];
                dpNode = {id: "dp" + dp.id, name: "<img src='images/icon_comp.png'/> " + dp.name, isFolder: true, parent:"dpRoot"};
                pointHierarchyStore.add(dpNode);

                for (j=0; j<dp.eventTypes.length; j++) {
                    et = dp.eventTypes[j];
                    createEventTypeNode("ped" + et.typeRef2, et, "dp" + dp.id);
                }
            }

            for (i=0; i<data.scheduledEvents.length; i++) {
                et = data.scheduledEvents[i];
                createEventTypeNode("se" + et.typeRef1, et, "seRoot");
            }

            // Default the selection of the parameter was provided.
            <c:if test="${!empty param.cedid}">
              showCompoundEvent(${param.cedid});
            </c:if>
        });
    }

    var editingCompoundEvent;

    function createEventTypeNode(id, eventType, parent) {
        var etNode = {id: id,
                name: getAlarmLevelHtmlImg(eventType.alarmLevel) + " " + eventType.description + " (" + eventType.eventDetectorKey + ")",
                isFolder: false,
                key: eventType.eventDetectorKey,
                parent: parent};
        pointHierarchyStore.add(etNode);
    }

    function showCompoundEvent(cedId) {
        if (editingCompoundEvent)
            stopImageFader(byId("ced"+ editingCompoundEvent.id +"Img"));
        CompoundEventsDwr.getCompoundEvent(cedId, function(ced) {
            if (!editingCompoundEvent) {
                show(byId("compoundEventDetails"));
                show(byId("eventTypes"));
            }
            editingCompoundEvent = ced;

            $set("xid", ced.xid);
            $set("name", ced.name);
            $set("alarmLevel", ced.alarmLevel);
            $set("rtn", ced.returnToNormal);
            $set("condition", ced.condition);
            $set("disabled", ced.disabled);

            setUserMessage();
        });
        startImageFader(byId("ced"+ cedId +"Img"));

        if (cedId == ${NEW_ID})
            hide(byId("deleteCompoundEventImg"));
        else
            show(byId("deleteCompoundEventImg"));
    }

    function saveCompoundEvent() {
        setUserMessage();
        hideContextualMessages("compoundEventDetails")

        CompoundEventsDwr.saveCompoundEvent(editingCompoundEvent.id, $get("xid"), $get("name"), $get("alarmLevel"),
                $get("rtn"), $get("condition"), $get("disabled"), function(response) {
            if (response.hasMessages) {
                showDwrMessages(response.messages);
                if (response.range)
                    setSelectionRange(byId("condition"), response.data.from, response.data.to);
            }
            else {
                if (editingCompoundEvent.id == ${NEW_ID}) {
                    stopImageFader(byId("ced"+ editingCompoundEvent.id +"Img"));
                    editingCompoundEvent.id = response.data.cedId;
                    appendCompoundEvent(editingCompoundEvent.id);
                    startImageFader(byId("ced"+ editingCompoundEvent.id +"Img"));
                    setUserMessage("<fmt:message key="compoundDetectors.cedAdded"/>");
                    show(byId("deleteCompoundEventImg"));
                }
                else
                    setUserMessage("<fmt:message key="compoundDetectors.cedSaved"/>");

                if (response.data.warning)
                    setUserMessage(response.data.warning);

                CompoundEventsDwr.getCompoundEvent(editingCompoundEvent.id, updateCompoundEvent)
            }
        });
    }

    function setUserMessage(message) {
        if (message) {
            show(byId("userMessage"));
            byId("userMessage").innerHTML = message;
        }
        else
            hide(byId("userMessage"));
    }

    function appendCompoundEvent(cedId) {
        createFromTemplate("ced_TEMPLATE_", cedId, "compoundEventsTable");
    }

    function updateCompoundEvent(ced) {
        byId("ced"+ ced.id +"Name").innerHTML = ced.name;
        setCompoundEventImg(ced.disabled, byId("ced"+ ced.id +"Img"));
    }

    function deleteCompoundEvent() {
        CompoundEventsDwr.deleteCompoundEvent(editingCompoundEvent.id, function() {
            stopImageFader(byId("ced"+ editingCompoundEvent.id +"Img"));
            byId("compoundEventsTable").removeChild(byId("ced"+ editingCompoundEvent.id));
            hide(byId("compoundEventDetails"));
            hide(byId("eventTypes"));
            editingCompoundEvent = null;
        });
    }

    function updateAlarmLevelImage(alarmLevel) {
        setAlarmLevelImg(alarmLevel, byId("alarmLevelImg"));
    }

    function validate() {
        setUserMessage();
        CompoundEventsDwr.validateCondition($get("condition"), function(response) {
            if (response.hasMessages) {
                showDwrMessages(response.messages);
                if (response.data.range)
                    setSelectionRange(byId("condition"), response.data.from, response.data.to);
            }
            else
                setUserMessage("<fmt:message key="compoundDetectors.cedValidated"/>");
        });
    }

    function insertText(text) {
        insertIntoTextArea(byId("condition"), text);
    }
  </script>
  <table>
    <tr>
      <td rowspan="2" valign="top">
        <div class="borderDiv">
          <table width="100%">
            <tr>
              <td>
                <span class="smallTitle"><fmt:message key="compoundDetectors.compoundEventDetectors"/></span>
                <tag:help id="compoundEventDetectors"/>
              </td>
              <td align="right"><tag:img png="multi_bell_add" title="common.add" id="ced${NEW_ID}Img"
                      onclick="showCompoundEvent(${NEW_ID})"/></td>
            </tr>
          </table>
          <table id="compoundEventsTable">
            <tbody id="ced_TEMPLATE_" onclick="showCompoundEvent(getMangoId(this))" class="ptr" style="display:none;">
              <tr>
                <td><tag:img id="ced_TEMPLATE_Img" png="multi_bell" title="compoundDetectors.compoundEventDetector"/></td>
                <td class="link" id="ced_TEMPLATE_Name"></td>
              </tr>
            </tbody>
          </table>
        </div>
      </td>

      <td valign="top" style="display:none;" id="compoundEventDetails">
        <div class="borderDiv">
          <table width="100%">
            <tr>
              <td><span class="smallTitle"><fmt:message key="compoundDetectors.details"/></span></td>
              <td align="right">
                <tag:img png="save" onclick="saveCompoundEvent();" title="common.save"/>
                <tag:img id="deleteCompoundEventImg" png="delete" onclick="deleteCompoundEvent();" title="common.delete"/>
              </td>
            </tr>
          </table>

          <table>
            <tr>
              <td class="formLabelRequired"><fmt:message key="common.xid"/></td>
              <td class="formField"><input type="text" id="xid"/></td>
            </tr>

            <tr>
              <td class="formLabelRequired"><fmt:message key="compoundDetectors.name"/></td>
              <td class="formField"><input type="text" id="name"/></td>
            </tr>

            <tr>
              <td class="formLabelRequired"><fmt:message key="common.alarmLevel"/></td>
              <td class="formField">
                <select id="alarmLevel" onchange="updateAlarmLevelImage(this.value)">
                  <tag:alarmLevelOptions/>
                </select>
                <tag:img id="alarmLevelImg" png="flag_green" title="common.alarmLevel.none" style="display:none;"/>
              </td>
            </tr>

            <tr>
              <td class="formLabelRequired"><fmt:message key="common.rtn"/></td>
              <td class="formField"><input type="checkbox" id="rtn"/></td>
            </tr>

            <tr>
              <td class="formLabelRequired">
                <fmt:message key="compoundDetectors.condition"/>
                <tag:img png="accept" onclick="validate();" title="compoundDetectors.validate"/><br/>
                <br/>
                <a href="#" onclick="insertText(' && '); return false;"><fmt:message key="compoundDetectors.and"/></a><br/>
                <a href="#" onclick="insertText(' || '); return false;"><fmt:message key="compoundDetectors.or"/></a><br/>
                <a href="#" onclick="insertText('!'); return false;"><fmt:message key="compoundDetectors.not"/></a><br/>
              </td>
              <td class="formField"><textarea rows="10" cols="60" id="condition"></textarea></td>
            </tr>

            <tr>
              <td class="formLabelRequired"><fmt:message key="common.disabled"/></td>
              <td class="formField"><input type="checkbox" id="disabled"/></td>
            </tr>
          </table>

          <table>
            <tr>
              <td colspan="2" id="userMessage" class="formError" style="display:none;"></td>
            </tr>
          </table>
        </div>
      </td>
    </tr>

    <tr>
      <td valign="top" style="display:none;" id="eventTypes">
        <div class="borderDivPadded">
          <span class="smallTitle"><fmt:message key="compoundDetectors.eventTypes"/></span>
          <div id="treeDiv"></div>
        </div>
      </td>
    </tr>
  </table>
</jsp:body>
</tag:page>