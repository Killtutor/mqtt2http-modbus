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
<%@page import="com.serotonin.mango.vo.event.EventHandlerVO"%>
<%@page import="com.serotonin.mango.DataTypes"%>
<c:set var="NEW_ID"><%= Common.NEW_ID %></c:set>

<tag:page dwr="EventHandlersDwr" js="Recipients" onload="init">
<jsp:attribute name="subtitle">
  <fmt:message key="header.eventHandlers"/>
</jsp:attribute>
<jsp:body>
  <script>
    require([
        "dojo/store/Memory", "dojo/store/Observable", "dijit/tree/ObjectStoreModel", "dijit/Tree", "dojo/_base/declare", "dojo/domReady!"
    ], function(Memory, Observable, ObjectStoreModel, Tree, declare){
        // Store
        pointHierarchyStore = new Memory({
            data: [
                { id: "root", name:'root', isFolder:true, hasChildren:true}
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
        tree = new Tree({
            model: pointHierarchyModel,
            showRoot: false,
            getIconClass: function(item, opened){
                return null;
            },
            _createTreeNode: function(args){
                return new MyTreeNode(args);
            },
            onClick: function(item, node, evt){
                var wid = item.id;
                if (wid.startsWith("ped") || wid.startsWith("sch") || wid.startsWith("ced") ||
                        wid.startsWith("dse") || wid.startsWith("pube") || wid.startsWith("sys") ||
                        wid.startsWith("aud") || wid.startsWith("maint")) {
                    selectedEventTypeNode = item;
                    selectedHandlerNode = null;
                    showHandlerEdit();
                }
                else if (wid.startsWith("h")) {
                    selectedHandlerNode = item;
                    selectedEventTypeNode = pointHierarchyStore.get(item.parent);
                    showHandlerEdit();
                }
                else
                    hide("handlerEditDiv");
            },
            onOpen: function(item, node){
                var children = pointHierarchyStore.getChildren(item);
                for(i=0;i<children.length;i++)
                    if(children[i].isFolder){
                        var node = this.getNodesByItem(children[i].id);
                        node[0].isExpandable=children[i].hasChildren;
                        node[0]._setExpando(false);
                    }
            }
        });
        tree.placeAt(byId("treeDiv"));
        tree.startup();
    });

    function init() {
        EventHandlersDwr.getInitData(initCB);
    }

    var allPoints;
    var defaultHandlerId;
    var emailRecipients;
    var smsRecipients;
    var escalRecipients;
    var inactiveRecipients;
    var escalSmsRecipients;
    var inactiveSmsRecipients;


    function initCB(data) {
        <c:if test="${!empty param.ehid}">
          defaultHandlerId = ${param.ehid};
        </c:if>

        var i, j, k;
        var dp, ds, p, et;
        var pointNode, dataSourceNode, publisherNode, etNode, wid;

        allPoints = data.allPoints;

        emailRecipients = new mango.erecip.EmailRecipients("emailRecipients",
                "<sst:i18n key="eventHandlers.recipTestEmailMessage" escapeDQuotes="true"/>",
                data.mailingLists, data.users);
        emailRecipients.write("emailRecipients", "emailRecipients", null,
                "<sst:i18n key="eventHandlers.emailRecipients" escapeDQuotes="true"/>");

        escalRecipients = new mango.erecip.EmailRecipients("escalRecipients",
                "<sst:i18n key="eventHandlers.escalTestEmailMessage" escapeDQuotes="true"/>",
                data.mailingLists, data.users);
        escalRecipients.write("escalRecipients", "escalRecipients", "escalationAddresses2",
                "<sst:i18n key="eventHandlers.escalRecipients" escapeDQuotes="true"/>");

        inactiveRecipients = new mango.erecip.EmailRecipients("inactiveRecipients",
                "<sst:i18n key="eventHandlers.inactiveTestEmailMessage" escapeDQuotes="true"/>",
                data.mailingLists, data.users);
        inactiveRecipients.write("inactiveRecipients", "inactiveRecipients", "inactiveAddresses2",
                "<sst:i18n key="eventHandlers.inactiveRecipients" escapeDQuotes="true"/>");


        smsRecipients = new mango.erecip.SmsRecipients("smsRecipients",
                "<sst:i18n key="eventHandlers.recipTestSmsMessage" escapeDQuotes="true"/>",
                data.phonesLists, data.users);
        smsRecipients.write("smsRecipients", "smsRecipients", null,
                "<sst:i18n key="eventHandlers.smsRecipients" escapeDQuotes="true"/>");

        escalSmsRecipients = new mango.erecip.SmsRecipients("smsEscalRecipients",
                "<sst:i18n key="eventHandlers.escalTestSmsMessage" escapeDQuotes="true"/>",
                data.phonesLists, data.users);
        escalSmsRecipients.write("escalSmsRecipients", "escalSmsRecipients", "escalationPhones2",
                "<sst:i18n key="eventHandlers.escalRecipients" escapeDQuotes="true"/>");

        inactiveSmsRecipients = new mango.erecip.SmsRecipients("inactiveSmsRecipients",
                "<sst:i18n key="eventHandlers.inactiveTestSmsMessage" escapeDQuotes="true"/>",
                data.phonesLists, data.users);
        inactiveSmsRecipients.write("inactiveSmsRecipients", "inactiveSmsRecipients", "inactivePhones2",
                "<sst:i18n key="eventHandlers.inactiveRecipients" escapeDQuotes="true"/>");


        // Compound events
        if(data.compoundEvents){
            var compoundRoot = {id: 'rootCompound', name: "<img src='images/multi_bell.png'/> <fmt:message key='compoundDetectors.compoundEventDetectors'/>",
                    isFolder: data.compoundEvents.length>0, parent: 'root'};
            pointHierarchyStore.add(compoundRoot);
            for (i=0; i<data.compoundEvents.length; i++) {
                et = data.compoundEvents[i];
                createEventTypeNode("ced"+ et.typeRef1, et, 'rootCompound');
            }
        }

        // Maintenance events
        if (data.maintenanceEvents) {
            var maintenanceRoot = {id: 'rootMaintenance', name: "<img src='images/hammer.png'/> <fmt:message key='eventHandlers.maintenanceEvents'/>",
                    isFolder: data.maintenanceEvents.length>0, parent: 'root'};
            pointHierarchyStore.add(maintenanceRoot);
            for (i=0; i<data.maintenanceEvents.length; i++) {
                et = data.maintenanceEvents[i];
                createEventTypeNode("maint"+ et.typeRef1, et, 'rootMaintenance');
            }
        }

        // Scheduled events
        if(data.scheduledEvents){
            var scheduledRoot = {id: 'rootScheduled', name: "<img src='images/clock.png'/> <fmt:message key='scheduledEvents.ses'/>",
                    isFolder: data.scheduledEvents.length>0, parent: 'root'};
            pointHierarchyStore.add(scheduledRoot);
            for (i=0; i<data.scheduledEvents.length; i++) {
                et = data.scheduledEvents[i];
                createEventTypeNode("sch"+ et.typeRef1, et, 'rootScheduled');
            }
        }

        // Point events
        if(data.dataPoints){
            var pointRoot = {id: 'rootPoint', name: "<img src='images/cog.png'/> <fmt:message key='eventHandlers.pointEventDetector'/>",
                    isFolder: data.dataPoints.length>0, parent: 'root'};
            pointHierarchyStore.add(pointRoot);
            for (i=0; i<data.dataPoints.length; i++) {
                dp = data.dataPoints[i];
                var pointNode = {id: "dp" + dp.id, name: "<img src='images/icon_comp.png'/> "+ dp.name, isFolder: true, hasChildren: true, parent: 'rootPoint'};
                pointHierarchyStore.add(pointNode);

                for (j=0; j<dp.eventTypes.length; j++) {
                    et = dp.eventTypes[j];
                    createEventTypeNode("ped"+ et.typeRef2, et, "dp" + dp.id);
                }
            }
        }

        // DataSource events
        if(data.dataSources){
            var dataSourceRoot = {id: 'rootDataSource', name: "<img src='images/cog.png'/> <fmt:message key='eventHandlers.dataSourceEvents'/>",
                    isFolder: data.dataSources.length>0, parent: 'root'};
            pointHierarchyStore.add(dataSourceRoot);
            for (i=0; i<data.dataSources.length; i++) {
                ds = data.dataSources[i];
                var dataSourceNode = {id: "ds" + ds.id, name: "<img src='images/icon_ds.png'/> "+ ds.name, isFolder: true, hasChildren: true, parent: 'rootDataSource'};
                pointHierarchyStore.add(dataSourceNode);

                for (j=0; j<ds.eventTypes.length; j++) {
                    et = ds.eventTypes[j];
                    createEventTypeNode("dse"+ et.typeRef1 +"/"+ et.typeRef2, et, "ds" + ds.id);
                }
            }
        }

        // Publisher events
        if (data.publishers) {
            var publisherRoot = {id: 'rootPublisher', name: "<img src='images/cog.png'/> <fmt:message key='eventHandlers.publisherEvents'/>",
                    isFolder: data.publishers.length>0, parent: 'root'};
            pointHierarchyStore.add(publisherRoot);
            for (i=0; i<data.publishers.length; i++) {
                p = data.publishers[i];
                var publisherNode = {id: "pub" + p.id, name: "<img src='images/transmit.png'/> "+ p.name, isFolder: true, hasChildren: true, parent: 'rootDataSource'};
                pointHierarchyStore.add(publisherNode);

                for (j=0; j<p.eventTypes.length; j++) {
                    et = p.eventTypes[j];
                    createEventTypeNode("pube"+ et.typeRef1 +"/"+ et.typeRef2, et, "pub" + p.id);
                }
            }
        }

        // System events
        if (data.systemEvents) {
            var systemRoot = {id: 'rootSystem', name: "<img src='images/cog.png'/> <fmt:message key='eventHandlers.systemEvents'/>",
                    isFolder: data.systemEvents.length>0, parent: 'root'};
            pointHierarchyStore.add(systemRoot);
            for (i=0; i<data.systemEvents.length; i++) {
                et = data.systemEvents[i];
                createEventTypeNode("sys"+ et.typeRef1, et, 'rootSystem');
            }
        }

        // Audit events
        if (data.auditEvents) {
            var auditRoot = {id: 'rootAudit', name: "<img src='images/cog.png'/> <fmt:message key='eventHandlers.auditEvents'/>",
                    isFolder: data.auditEvents.length>0, parent: 'root'};
            pointHierarchyStore.add(auditRoot);
            for (i=0; i<data.auditEvents.length; i++) {
                et = data.auditEvents[i];
                createEventTypeNode("aud"+ et.typeRef1, et, 'rootAudit');
            }
        }

        hide("loadingImg");
        show("treeDiv");

        // Default the selection of the parameter was provided.
        if (selectedHandlerNode) {
            selectedHandlerNode.onTitleClick();
            var parent = selectedHandlerNode.parent;
            while (parent && parent.expand) {
                parent.expand();
                parent = parent.parent;
            }
        }
        defaultHandlerId = null;
    }

    function createEventTypeNode(id, eventType, parent) {
        var node = {id: id,
                name: getAlarmLevelHtmlImg(eventType.alarmLevel) + " " + eventType.description,
                isFolder: true,
                hasChildren: eventType.handlers.length>0,
                object: eventType,
                parent: parent};

        pointHierarchyStore.add(node);
        addHandlerNodes(eventType.handlers, node.id);
    }

    function addHandlerNodes(handlers, parent) {
        for (var i=0; i<handlers.length; i++)
            pointHierarchyStore.add(createHandlerNode(handlers[i], parent));
    }

    function createHandlerNode(handler, parent) {
        var img = "images/cog_wrench.png";
        if (handler.handlerType == <c:out value="<%= EventHandlerVO.TYPE_EMAIL %>"/>)
            img = "images/cog_email.png";
        else if (handler.handlerType == <c:out value="<%= EventHandlerVO.TYPE_PROCESS %>"/>)
            img = "images/cog_process.png";
        if (handler.handlerType == <c:out value="<%= EventHandlerVO.TYPE_SMS %>"/>)
            img = "images/cog_sms.png";

        var node = {id: "h" + handler.id,
                name: "<img src='"+ img +"'/> <span id='"+ handler.id +"Msg'>"+ handler.message +"</span>",
                isFolder: false,
                object: handler,
                parent: parent
                };

        if (handler.id == defaultHandlerId)
            selectedHandlerNode = node;

        return node;
    }

    var selectedEventTypeNode;
    var selectedHandlerNode;

    function showHandlerEdit() {
        show("handlerEditDiv");
        setUserMessage("");

        // Set the target points.
        var pointSelect = byId("targetPointSelect");
        dwr.util.removeAllOptions(pointSelect);
        for (var i=0; i<allPoints.length; i++) {
            dp = allPoints[i];
            if (dp.settable)
                pointSelect.options[pointSelect.options.length] = new Option(dp.name, dp.id);
        }

        if (selectedHandlerNode) {
            byId("saveImg").src = "images/save.png";
            show("deleteImg");

            // Put values from the handler object into the input controls.
            var handler = selectedHandlerNode.object;
            $set("handlerTypeSelect", handler.handlerType);
            byId("handlerTypeSelect").disabled = true;
            $set("xid", handler.xid);
            $set("alias", handler.alias);
            $set("disabled", handler.disabled);
            if (handler.handlerType == <c:out value="<%= EventHandlerVO.TYPE_SET_POINT %>"/>) {
                $set("targetPointSelect", handler.targetPointId);
                $set("activeAction", handler.activeAction);
                $set("inactiveAction", handler.inactiveAction);
            }
            else if (handler.handlerType == <c:out value="<%= EventHandlerVO.TYPE_EMAIL %>"/>) {
                emailRecipients.updateRecipientList(handler.activeRecipients);
                $set("sendEscalation", handler.sendEscalation);
                $set("escalationDelayType", handler.escalationDelayType);
                $set("escalationDelay", handler.escalationDelay);
                escalRecipients.updateRecipientList(handler.escalationRecipients);
                $set("sendInactive", handler.sendInactive);
                $set("inactiveOverride", handler.inactiveOverride);
                inactiveRecipients.updateRecipientList(handler.inactiveRecipients);
            }
            else if (handler.handlerType == <c:out value="<%= EventHandlerVO.TYPE_PROCESS %>"/>) {
                $set("activeProcessCommand", handler.activeProcessCommand);
                $set("inactiveProcessCommand", handler.inactiveProcessCommand);
            }
            else if (handler.handlerType == <c:out value="<%= EventHandlerVO.TYPE_SMS %>"/>) {
                smsRecipients.updateRecipientList(handler.activeSmsRecipients);
                $set("sendSmsEscalation", handler.sendEscalation);
                $set("escalationSmsDelayType", handler.escalationDelayType);
                $set("escalationSmsDelay", handler.escalationDelay);
                escalSmsRecipients.updateRecipientList(handler.escalationSmsRecipients);
                $set("sendSmsInactive", handler.sendInactive);
                $set("inactiveSmsOverride", handler.inactiveOverride);
                inactiveSmsRecipients.updateRecipientList(handler.inactiveSmsRecipients);
            }
        }
        else {
            byId("saveImg").src = "images/save_add.png";
            hide("deleteImg");
            byId("handlerTypeSelect").disabled = false;

            // Clear values that may be left over from another handler.
            $set("xid", "");
            $set("alias", "");
            $set("disabled", false);
            $set("activeAction", <c:out value="<%= EventHandlerVO.SET_ACTION_NONE %>"/>);
            $set("inactiveAction", <c:out value="<%= EventHandlerVO.SET_ACTION_NONE %>"/>);
            $set("sendEscalation", false);
            $set("sendSmsEscalation", false);
            $set("escalationDelayType", <c:out value="<%= Common.TimePeriods.HOURS %>"/>);
            $set("escalationSmsDelayType", <c:out value="<%= Common.TimePeriods.HOURS %>"/>);
            $set("escalationDelay", 1);
            $set("escalationSmsDelay", 1);
            $set("sendInactive", false);
            $set("sendSmsInactive", false);
            $set("inactiveOverride", false);
            $set("activeProcessCommand", "");
            $set("inactiveProcessCommand", "");

            // Clear the recipient lists.
            emailRecipients.updateRecipientList();
            escalRecipients.updateRecipientList();
            inactiveRecipients.updateRecipientList();

            smsRecipients.updateRecipientList();
            escalSmsRecipients.updateRecipientList();
            inactiveSmsRecipients.updateRecipientList();


        }

        // Set the use source value checkbox.
        handlerTypeChanged();
        activeActionChanged();
        inactiveActionChanged();
        targetPointSelectChanged();
        sendEscalationChanged();
        sendInactiveChanged();
        sendSmsEscalationChanged();
        sendSmsInactiveChanged();
    }

    var currentHandlerEditor;
    function handlerTypeChanged() {
        setUserMessage();
        var handlerId = $get("handlerTypeSelect");
        if (currentHandlerEditor) {
            hide(currentHandlerEditor);
            hide(byId(currentHandlerEditor.id +"Img"));
        }
        currentHandlerEditor = byId("handler"+ handlerId);
        show(currentHandlerEditor);
        show(byId(currentHandlerEditor.id +"Img"));
    }

    function targetPointSelectChanged() {
        var selectControl = byId("targetPointSelect");

        // Make sure there are points in the list.
        if (selectControl.options.length == 0)
            return;

        // Get the content for the value to set section.
        var targetPointId = selectControl.value;
        var activeValueStr = "";
        var inactiveValueStr = "";
        if (selectedHandlerNode) {
            activeValueStr = selectedHandlerNode.object.activeValueToSet;
            inactiveValueStr = selectedHandlerNode.object.inactiveValueToSet;
        }
        EventHandlersDwr.createSetValueContent(targetPointId, activeValueStr, "Active",
                function(content) { byId("activeValueToSetContent").innerHTML = content; });
        EventHandlersDwr.createSetValueContent(targetPointId, inactiveValueStr, "Inactive",
                function(content) { byId("inactiveValueToSetContent").innerHTML = content; });

        // Update the source point lists.
        var targetDataTypeId = getPoint(targetPointId).dataType;
        var activeSourceSelect = byId("activePointId");
        dwr.util.removeAllOptions(activeSourceSelect);
        var inactiveSourceSelect = byId("inactivePointId");
        dwr.util.removeAllOptions(inactiveSourceSelect);
        for (var i=0; i<allPoints.length; i++) {
            dp = allPoints[i];
            if (dp.id != targetPointId && dp.dataType == targetDataTypeId) {
                activeSourceSelect.options[activeSourceSelect.options.length] = new Option(dp.name, dp.id);
                inactiveSourceSelect.options[activeSourceSelect.options.length] = new Option(dp.name, dp.id);
            }
        }
        if (selectedHandlerNode) {
            $set(activeSourceSelect, selectedHandlerNode.object.activePointId);
            $set(inactiveSourceSelect, selectedHandlerNode.object.inactivePointId);
        }
    }

    function activeActionChanged() {
        var action = $get("activeAction");
        if (action == <c:out value="<%= EventHandlerVO.SET_ACTION_POINT_VALUE %>"/>) {
            show("activePointIdRow");
            hide("activeValueToSetRow");
        }
        else if (action == <c:out value="<%= EventHandlerVO.SET_ACTION_STATIC_VALUE %>"/>) {
            hide("activePointIdRow");
            show("activeValueToSetRow");
        }
        else {
            hide("activePointIdRow");
            hide("activeValueToSetRow");
        }
    }

    function inactiveActionChanged() {
        var action = $get("inactiveAction");
        if (action == <c:out value="<%= EventHandlerVO.SET_ACTION_POINT_VALUE %>"/>) {
            show("inactivePointIdRow");
            hide("inactiveValueToSetRow");
        }
        else if (action == <c:out value="<%= EventHandlerVO.SET_ACTION_STATIC_VALUE %>"/>) {
            hide("inactivePointIdRow");
            show("inactiveValueToSetRow");
        }
        else {
            hide("inactivePointIdRow");
            hide("inactiveValueToSetRow");
        }
    }

    function sendEscalationChanged() {
        if ($get("sendEscalation")) {
            show("escalationAddresses1");
            show("escalationAddresses2");
        }
        else {
            hide("escalationAddresses1");
            hide("escalationAddresses2");
        }
    }

    function sendSmsEscalationChanged() {
        if ($get("sendSmsEscalation")) {
            show("escalationPhones1");
            show("escalationPhones2");
        }
        else {
            hide("escalationPhones1");
            hide("escalationPhones2");
        }
    }

    function getPoint(id) {
        return getElement(allPoints, id);
    }

    function saveHandler() {
        setUserMessage();
        //hideContextualMessages("scheduledEventDetails")
        hideGenericMessages("genericMessages")

        var handlerId = ${NEW_ID};
        if (selectedHandlerNode)
            handlerId = selectedHandlerNode.object.id;


        // Do some validation.
        var handlerType = $get("handlerTypeSelect");
        var xid = $get("xid");
        var alias = $get("alias");
        var disabled = $get("disabled");
        if (handlerType == <c:out value="<%= EventHandlerVO.TYPE_EMAIL %>"/>) {
            var emailList = emailRecipients.createRecipientArray();
            var escalList = escalRecipients.createRecipientArray();
            var inactiveList = inactiveRecipients.createRecipientArray();
            EventHandlersDwr.saveEmailEventHandler(selectedEventTypeNode.object.typeId,
                    selectedEventTypeNode.object.typeRef1, selectedEventTypeNode.object.typeRef2, handlerId, xid, alias,
                    disabled, emailList, $get("sendEscalation"), $get("escalationDelayType"), $get("escalationDelay"),
                    escalList, $get("sendInactive"), $get("inactiveOverride"), inactiveList, saveEventHandlerCB);
        }
        else if (handlerType == <c:out value="<%= EventHandlerVO.TYPE_SET_POINT %>"/>) {
            EventHandlersDwr.saveSetPointEventHandler(selectedEventTypeNode.object.typeId,
                    selectedEventTypeNode.object.typeRef1, selectedEventTypeNode.object.typeRef2, handlerId, xid, alias,
                    disabled, $get("targetPointSelect"), $get("activeAction"), $get("setPointValueActive"),
                    $get("activePointId"), $get("inactiveAction"), $get("setPointValueInactive"),
                    $get("inactivePointId"), saveEventHandlerCB);
        }
        else if (handlerType == <c:out value="<%= EventHandlerVO.TYPE_PROCESS %>"/>) {
            EventHandlersDwr.saveProcessEventHandler(selectedEventTypeNode.object.typeId,
                    selectedEventTypeNode.object.typeRef1, selectedEventTypeNode.object.typeRef2, handlerId, xid,
                    alias, disabled, $get("activeProcessCommand"), $get("inactiveProcessCommand"), saveEventHandlerCB);
        }
        if (handlerType == <c:out value="<%= EventHandlerVO.TYPE_SMS %>"/>) {
            var phonesList = smsRecipients.createRecipientArray();
            var escalSmsList = escalSmsRecipients.createRecipientArray();
            var inactiveSmsList = inactiveSmsRecipients.createRecipientArray();

            EventHandlersDwr.saveSmsEventHandler(selectedEventTypeNode.object.typeId,
                    selectedEventTypeNode.object.typeRef1, selectedEventTypeNode.object.typeRef2, handlerId, xid, alias,
                    disabled, phonesList, $get("sendSmsEscalation"), $get("escalationSmsDelayType"), $get("escalationSmsDelay"),
                    escalSmsList, $get("sendSmsInactive"), $get("inactiveSmsOverride"), inactiveSmsList, saveEventHandlerCB);
        }
    }

    function saveEventHandlerCB(response) {
        if (response.hasMessages)
            showDwrMessages(response.messages, byId("genericMessages"));
        else {
            var handler = response.data.handler;
            setUserMessage("<fmt:message key="eventHandlers.saved"/>");
            if (!selectedHandlerNode) {
                selectedHandlerNode = createHandlerNode(handler,selectedEventTypeNode.id);
                pointHierarchyStore.add(selectedHandlerNode);
                selectedEventTypeNode.hasChildren=true;
                var nodes = tree.getNodesByItem(selectedEventTypeNode.id);
                tree._expandNode(nodes[0]);
            }
            else
                $set(handler.id +"Msg", handler.message);
        }
    }

    function deleteHandler() {
        EventHandlersDwr.deleteEventHandler(selectedHandlerNode.object.id);
        pointHierarchyStore.remove(selectedHandlerNode.id);
        var children = pointHierarchyStore.getChildren(selectedEventTypeNode);
        if(children.length==0)
            selectedEventTypeNode.hasChildren=false;
        hide("handlerEditDiv");
    }

    function setUserMessage(msg) {
        showMessage("userMessage", msg);
    }

    function testProcessCommand(nodeId) {
        EventHandlersDwr.testProcessCommand($get(nodeId), function(msg) {
            if (msg)
                alert(msg);
        });
    }

    function sendInactiveChanged() {
        if ($get("sendInactive")) {
            show("inactiveAddresses1");
            inactiveOverrideChanged();
        }
        else {
            hide("inactiveAddresses1");
            hide("inactiveAddresses2");
        }
    }

    function sendSmsInactiveChanged() {
        if ($get("sendSmsInactive")) {
            show("inactivePhones1");
            inactiveSmsOverrideChanged();
        }
        else {
            hide("inactivePhones1");
            hide("inactivePhones2");
        }
    }

    function inactiveOverrideChanged() {
        if ($get("inactiveOverride"))
            show("inactiveAddresses2");
        else
            hide("inactiveAddresses2");
    }

    function inactiveSmsOverrideChanged() {
        if ($get("inactiveSmsOverride"))
            show("inactivePhones2");
        else
            hide("inactivePhones2");
    }

  </script>

  <table class="borderDiv marB"><tr><td>
    <tag:img png="cog" title="eventHandlers.eventHandlers"/>
    <span class="smallTitle"><fmt:message key="eventHandlers.eventHandlers"/></span>
    <tag:help id="eventHandlers"/>
  </td></tr></table>

  <table cellpadding="0" cellspacing="0">
    <tr>
      <td valign="top">
        <div class="borderDivPadded marR">
          <span class="smallTitle"><fmt:message key="eventHandlers.types"/></span>
          <img src="images/hourglass.png" id="loadingImg"/>
          <div id="treeDiv" style="display:none;"></div>
        </div>
      </td>

      <td valign="top">
        <div id="handlerEditDiv" class="borderDivPadded" style="display:none;">
          <table width="100%">
            <tr>
              <td class="smallTitle"><fmt:message key="eventHandlers.eventHandler"/></td>
              <td align="right">
                <tag:img id="deleteImg" png="delete" title="common.delete" onclick="deleteHandler();"/>
                <tag:img id="saveImg" png="save" title="common.save" onclick="saveHandler();"/>
              </td>
            </tr>
            <tr><td class="formError" id="userMessage"></td></tr>
          </table>

          <table width="100%">
            <tr>
              <td class="formLabelRequired"><fmt:message key="eventHandlers.type"/></td>
              <td class="formField">
                <select id="handlerTypeSelect" onchange="handlerTypeChanged()">
                  <option value="<c:out value="<%= EventHandlerVO.TYPE_EMAIL %>"/>"><fmt:message key="eventHandlers.type.email"/></option>
                  <option value="<c:out value="<%= EventHandlerVO.TYPE_SMS %>"/>"><fmt:message key="eventHandlers.type.sms"/></option>
                  <option value="<c:out value="<%= EventHandlerVO.TYPE_SET_POINT %>"/>"><fmt:message key="eventHandlers.type.setPoint"/></option>
                  <option value="<c:out value="<%= EventHandlerVO.TYPE_PROCESS %>"/>"><fmt:message key="eventHandlers.type.process"/></option>
                </select>
                <tag:img id="handler1Img" png="cog_wrench" title="eventHandlers.type.setPointHandler" style="display:none;"/>
                <tag:img id="handler2Img" png="cog_email" title="eventHandlers.type.emailHandler" style="display:none;"/>
                <tag:img id="handler3Img" png="cog_process" title="eventHandlers.type.processHandler" style="display:none;"/>
                <tag:img id="handler4Img" png="cog_sms" title="eventHandlers.type.smsHandler" style="display:none;"/>
              </td>
            </tr>

            <tr>
              <td class="formLabelRequired"><fmt:message key="common.xid"/></td>
              <td class="formField"><input type="text" id="xid"/></td>
            </tr>

            <tr>
              <td class="formLabelRequired"><fmt:message key="eventHandlers.alias"/></td>
              <td class="formField"><input id="alias" type="text"/></td>
            </tr>

            <tr>
              <td class="formLabelRequired"><fmt:message key="common.disabled"/></td>
              <td class="formField"><input type="checkbox" id="disabled"/></td>
            </tr>

            <tr><td class="horzSeparator" colspan="2"></td></tr>
          </table>

          <table id="handler<c:out value="<%= EventHandlerVO.TYPE_SET_POINT %>"/>" style="display:none" width="100%">
            <tr>
              <td class="formLabelRequired"><fmt:message key="eventHandlers.target"/></td>
              <td class="formField">
                <select id="targetPointSelect" onchange="targetPointSelectChanged()"></select>
              </td>
            </tr>

            <tr>
              <td class="formLabelRequired"><fmt:message key="eventHandlers.activeAction"/></td>
              <td class="formField">
                <select id="activeAction" onchange="activeActionChanged()">
                  <option value="<c:out value="<%= EventHandlerVO.SET_ACTION_NONE %>"/>"><fmt:message key="eventHandlers.action.none"/></option>
                  <option value="<c:out value="<%= EventHandlerVO.SET_ACTION_POINT_VALUE %>"/>"><fmt:message key="eventHandlers.action.point"/></option>
                  <option value="<c:out value="<%= EventHandlerVO.SET_ACTION_STATIC_VALUE %>"/>"><fmt:message key="eventHandlers.action.static"/></option>
                </select>
              </td>
            </tr>

            <tr id="activePointIdRow">
              <td class="formLabel"><fmt:message key="eventHandlers.sourcePoint"/></td>
              <td class="formField"><select id="activePointId"></select></td>
            </tr>

            <tr id="activeValueToSetRow">
              <td class="formLabel"><fmt:message key="eventHandlers.valueToSet"/></td>
              <td class="formField" id="activeValueToSetContent"></td>
            </tr>

            <tr>
              <td class="formLabelRequired"><fmt:message key="eventHandlers.inactiveAction"/></td>
              <td class="formField">
                <select id="inactiveAction" onchange="inactiveActionChanged()">
                  <option value="<c:out value="<%= EventHandlerVO.SET_ACTION_NONE %>"/>"><fmt:message key="eventHandlers.action.none"/></option>
                  <option value="<c:out value="<%= EventHandlerVO.SET_ACTION_POINT_VALUE %>"/>"><fmt:message key="eventHandlers.action.point"/></option>
                  <option value="<c:out value="<%= EventHandlerVO.SET_ACTION_STATIC_VALUE %>"/>"><fmt:message key="eventHandlers.action.static"/></option>
                </select>
              </td>
            </tr>

            <tr id="inactivePointIdRow">
              <td class="formLabel"><fmt:message key="eventHandlers.sourcePoint"/></td>
              <td class="formField"><select id="inactivePointId"></select></td>
            </tr>

            <tr id="inactiveValueToSetRow">
              <td class="formLabel"><fmt:message key="eventHandlers.valueToSet"/></td>
              <td class="formField" id="inactiveValueToSetContent"></td>
            </tr>
          </table>

          <table id="handler<c:out value="<%= EventHandlerVO.TYPE_EMAIL %>"/>" style="display:none" width="100%">
            <tbody id="emailRecipients"></tbody>

            <tr><td class="horzSeparator" colspan="2"></td></tr>

            <tr>
              <td class="formLabelRequired"><fmt:message key="eventHandlers.escal"/></td>
              <td class="formField"><input id="sendEscalation" type="checkbox" onclick="sendEscalationChanged()"/></td>
            </tr>

            <tr id="escalationAddresses1">
              <td class="formLabelRequired"><fmt:message key="eventHandlers.escalPeriod"/></td>
              <td class="formField">
                <input id="escalationDelay" type="text" class="formShort"/>
                <select id="escalationDelayType">
                  <tag:timePeriodOptions min="true" h="true" d="true"/>
                </select>
              </td>
            </tr>

            <tbody id="escalRecipients"></tbody>

            <tr><td class="horzSeparator" colspan="2"></td></tr>

            <tr>
              <td class="formLabelRequired"><fmt:message key="eventHandlers.inactiveNotif"/></td>
              <td class="formField"><input id="sendInactive" type="checkbox" onclick="sendInactiveChanged()"/></td>
            </tr>

            <tr id="inactiveAddresses1">
              <td class="formLabelRequired"><fmt:message key="eventHandlers.inactiveOverride"/></td>
              <td class="formField"><input id="inactiveOverride" type="checkbox" onclick="inactiveOverrideChanged()"/></td>
            </tr>

            <tbody id="inactiveRecipients"></tbody>
          </table>

          <table id="handler<c:out value="<%= EventHandlerVO.TYPE_PROCESS %>"/>" style="display:none" width="100%">
            <tr>
              <td class="formLabelRequired"><fmt:message key="eventHandlers.activeCommand"/></td>
              <td class="formField">
                <input type="text" id="activeProcessCommand" class="formLong"/>
                <tag:img png="cog_go" onclick="testProcessCommand('activeProcessCommand')" title="eventHandlers.commandTest.title"/>
              </td>
            </tr>

            <tr>
              <td class="formLabelRequired"><fmt:message key="eventHandlers.inactiveCommand"/></td>
              <td class="formField">
                <input type="text" id="inactiveProcessCommand" class="formLong"/>
                <tag:img png="cog_go" onclick="testProcessCommand('inactiveProcessCommand')" title="eventHandlers.commandTest.title"/>
              </td>
            </tr>
          </table>
          <table id="handler<c:out value="<%= EventHandlerVO.TYPE_SMS %>"/>" style="display:none" width="100%">
            <tbody id="smsRecipients"></tbody>

            <tr><td class="horzSeparator" colspan="2"></td></tr>

            <tr>
              <td class="formLabelRequired"><fmt:message key="eventHandlers.escal"/></td>
              <td class="formField"><input id="sendSmsEscalation" type="checkbox" onclick="sendSmsEscalationChanged()"/></td>
            </tr>

            <tr id="escalationPhones1">
              <td class="formLabelRequired"><fmt:message key="eventHandlers.escalPeriod"/></td>
              <td class="formField">
                <input id="escalationSmsDelay" type="text" class="formShort"/>
                <select id="escalationSmsDelayType">
                  <tag:timePeriodOptions min="true" h="true" d="true"/>
                </select>
              </td>
            </tr>

            <tbody id="escalSmsRecipients"></tbody>

            <tr><td class="horzSeparator" colspan="2"></td></tr>

            <tr>
              <td class="formLabelRequired"><fmt:message key="eventHandlers.inactiveNotif"/></td>
              <td class="formField"><input id="sendSmsInactive" type="checkbox" onclick="sendSmsInactiveChanged()"/></td>
            </tr>

            <tr id="inactivePhones1">
              <td class="formLabelRequired"><fmt:message key="eventHandlers.inactiveOverride"/></td>
              <td class="formField"><input id="inactiveSmsOverride" type="checkbox" onclick="inactiveSmsOverrideChanged()"/></td>
            </tr>

            <tbody id="inactiveSmsRecipients"></tbody>
          </table>
          <table>
            <tbody id="genericMessages"></tbody>
          </table>
        </div>
      </td>
    </tr>
  </table>
</jsp:body>
</tag:page>