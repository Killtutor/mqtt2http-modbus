<%--
    Mango - Open Source M2M - http://mango.serotoninsoftware.com
    Copyright (C) 2010 Arne Pl�se
    @author Arne Pl�se

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

<script type="text/javascript">
    var deviceInfo;

    /**
     * called from init()
     */
    function initImpl() {
        searchButtons(false);
        updateModemOrDirect();
        hide("editImg"+ <c:out value="<%= Common.NEW_ID %>"/>);
    }

    /**
     * enabele/disable search buttons
     */
    function searchButtons(searching) {
        setDisabled("searchBtn", searching);
        setDisabled("cancelSearchBtn", !searching);
    }

    function search() {
        searchButtons(true);
        $set("searchMessage", "<fmt:message key='dsEdit.mbus.searching' />");
        dwr.util.removeAllRows("mbusDevices");
        if ($get("addressingType") == "PRIMARY") {
            DataSourceEditDwr.searchMBusByPrimaryAddressing($get("commPortId"), $get("phonenumber"),
                $get("baudRate"),  $get("flowControlIn"),  $get("flowControlOut"),
                $get("dataBits"),  $get("stopBits"),  $get("parity"),
                $get("firstPrimaryAddress"), $get("lastPrimaryAddress"),
                searchCB);
        } else if ($get("addressingType") == "SECONDARY") {
            DataSourceEditDwr.searchMBusBySecondaryAddressing($get("commPortId"), $get("phonenumber"),
                $get("baudRate"),  $get("flowControlIn"),  $get("flowControlOut"),
                $get("dataBits"),  $get("stopBits"),  $get("parity"),
                searchCB);

        } else {
            DataSourceEditDwr.searchMBusByUnknownAddress();// Dummy for generating Error in log
        }
    }

    function searchCB() {
        searchButtons(true);
        $set("searchMessage", "Callback searchCB");
        setTimeout(searchUpdate, 1000);
    }

    function searchUpdate() {
        DataSourceEditDwr.mBusSearchUpdate(searchUpdateCB);
    }

    function searchUpdateCB(result) {
        if (result) {
            $set("searchMessage", result.message);
            dwr.util.removeAllRows("mbusDevices");
            dwr.util.addRows("mbusDevices", result.devices, [
                function(device) { return device.addressHex; },
                function(device) { return device.identNumber; },
                function(device) { return device.medium; },
                function(device) { return device.manufacturer; },
                function(device) { return device.versionHex; },
                function(device) {
                    return writeImage("responseFramesImg"+ device.index, null, "control_play_blue",
                    "<fmt:message key='dsEditMbus.getDetails'/>", "getResponseFrames(" + device.index + ")");
                }

            ],
            {
                rowCreator: function(options) {
                    var tr = document.createElement("tr");
                    tr.id = "deviceIndex"+ options.rowData.id;
                    tr.className = "row"+ (options.rowIndex % 2 == 0 ? "" : "Alt");
                    return tr;
                }
            });

            hide("responseFrames");

            if (result.finished) {
                $set("searchMessage", "searchUpdateCB");
                searchButtons(false);
            } else {
                searchCB();
            }
        }
    }

    function getResponseFrames(index) {
        startImageFader("responseFramesImg"+ index, true);
        DataSourceEditDwr.getMBusResponseFrames(index, getResponseFramesCB);
    }

    function getResponseFramesCB(result) {
        if (result) {
            stopImageFader("responseFramesImg"+ result.deviceIndex);

            show("responseFrames");
            var tree = dojo.widget.manager.getWidgetById("responseFramesTree");

            // Remove all of the old results.
            while (tree.children.length > 0)
                tree.removeNode(tree.children[0]);

            // Add the new stuff.
            var deviceNode = dojo.widget.createWidget("TreeNode", {
                title: "<b>" + result.deviceName  + "</b>", isFolder: "true" });
            tree.addChild(deviceNode);

            for (var rsIndex = 0; rsIndex < result.responseFrames.length; rsIndex++) {
                var responseFrame = result.responseFrames[rsIndex];
                var responseFrameNode = dojo.widget.createWidget("TreeNode", {
                    title: responseFrame.name, isFolder: "true"});
                deviceNode.addChild(responseFrameNode);

                for (var dbIndex = 0; dbIndex < responseFrame.dataBlocks.length; dbIndex++) {
                    var dataBlock = responseFrame.dataBlocks[dbIndex];
                    var dataBlockNode = dojo.widget.createWidget("TreeNode", {
                        title: dataBlock.name + "(" + dataBlock.params  + ")" + writeImageSQuote(null, null,
                        "icon_comp_add", "<fmt:message key='dsEdit.mbus.addPoint'/>", "addPoint( { addressing: \"" + result.addressing + "\", deviceIndex: "+ result.deviceIndex + ", rsIndex: " + rsIndex + ", dbIndex: " + dbIndex + "})"),
                        isFolder: "true"});
                    responseFrameNode.addChild(dataBlockNode);

                    dataBlockNode.addChild(dojo.widget.createWidget("TreeNode",
                    { title: "<fmt:message key='dsEdit.mbus.presentValue'/>: "+ dataBlock.value}));
                }

            }

            deviceNode.expand();
        }
    }


    function cancelSearch() {
        DataSourceEditDwr.cancelTestingUtility(cancelSearchCB);
    }

    function cancelSearchCB() {
        $set("searchMessage", "<fmt:message key='dsEdit.mbus.seachStopped'/>");
        searchButtons(false);
    }

    function saveDataSourceImpl() {
            DataSourceEditDwr.saveMBusDataSourceConnection($get("dataSourceName"), $get("dataSourceXid"),
            $get("useModemOrDirectConnection"), $get("commPortId"), $get("phonenumber"),
            $get("baudRate"),  $get("flowControlIn"),  $get("flowControlOut"),
            $get("dataBits"),  $get("stopBits"),  $get("parity"),
            $get("updatePeriodType"), $get("updatePeriods"), saveDataSourceCB);
    }


    function appendPointListColumnFunctions(pointListColumnHeaders, pointListColumnFunctions) {
        pointListColumnHeaders[pointListColumnHeaders.length] = "<fmt:message key='dsEdit.mbus.addressing'/>";
        pointListColumnFunctions[pointListColumnFunctions.length] = function(p) { return p.pointLocator.addressing; };

        pointListColumnHeaders[pointListColumnHeaders.length] = "<fmt:message key='dsEdit.mbus.addressHex'/>";
        pointListColumnFunctions[pointListColumnFunctions.length] = function(p) { return p.pointLocator.addressHex; };

        pointListColumnHeaders[pointListColumnHeaders.length] = "<fmt:message key='dsEdit.mbus.identNumber'/>";
        pointListColumnFunctions[pointListColumnFunctions.length] = function(p) { return p.pointLocator.identNumber; };

        pointListColumnHeaders[pointListColumnHeaders.length] = "<fmt:message key='dsEdit.mbus.medium'/>";
        pointListColumnFunctions[pointListColumnFunctions.length] = function(p) { return p.pointLocator.medium; };

        pointListColumnHeaders[pointListColumnHeaders.length] = "<fmt:message key='dsEdit.mbus.manufacturer'/>";
        pointListColumnFunctions[pointListColumnFunctions.length] = function(p) { return p.pointLocator.manufacturer; };

        pointListColumnHeaders[pointListColumnHeaders.length] = "<fmt:message key='dsEdit.mbus.versionHex'/>";
        pointListColumnFunctions[pointListColumnFunctions.length] = function(p) { return p.pointLocator.versionHex; };

        pointListColumnHeaders[pointListColumnHeaders.length] = "<fmt:message key='dsEdit.mbus.responseFrame'/>";
        pointListColumnFunctions[pointListColumnFunctions.length] = function(p) { return p.pointLocator.responseFrame; };

        pointListColumnHeaders[pointListColumnHeaders.length] = "<fmt:message key='dsEdit.mbus.difCode'/>";
        pointListColumnFunctions[pointListColumnFunctions.length] = function(p) { return p.pointLocator.difCode; };

        pointListColumnHeaders[pointListColumnHeaders.length] = "<fmt:message key='dsEdit.mbus.functionField'/>";
        pointListColumnFunctions[pointListColumnFunctions.length] = function(p) { return p.pointLocator.functionField; };

        pointListColumnHeaders[pointListColumnHeaders.length] = "<fmt:message key='dsEdit.mbus.deviceUnit'/>";
        pointListColumnFunctions[pointListColumnFunctions.length] = function(p) { return p.pointLocator.deviceUnit; };

        pointListColumnHeaders[pointListColumnHeaders.length] = "<fmt:message key='dsEdit.mbus.tariff'/>";
        pointListColumnFunctions[pointListColumnFunctions.length] = function(p) { return p.pointLocator.tariff; };

        pointListColumnHeaders[pointListColumnHeaders.length] = "<fmt:message key='dsEdit.mbus.storageNumber'/>";
        pointListColumnFunctions[pointListColumnFunctions.length] = function(p) { return p.pointLocator.storageNumber; };

        pointListColumnHeaders[pointListColumnHeaders.length] = "<fmt:message key='dsEdit.mbus.vifType'/>";
        pointListColumnFunctions[pointListColumnFunctions.length] = function(p) { return p.pointLocator.vifType; };

        pointListColumnHeaders[pointListColumnHeaders.length] = "<fmt:message key='dsEdit.mbus.vifLabel'/>";
        pointListColumnFunctions[pointListColumnFunctions.length] = function(p) { return p.pointLocator.vifLabel; };

        pointListColumnHeaders[pointListColumnHeaders.length] = "<fmt:message key='dsEdit.mbus.unitOfMeasurement'/>";
        pointListColumnFunctions[pointListColumnFunctions.length] = function(p) { return p.pointLocator.unitOfMeasurement; };

        pointListColumnHeaders[pointListColumnHeaders.length] = "<fmt:message key='dsEdit.mbus.siPrefix'/>";
        pointListColumnFunctions[pointListColumnFunctions.length] = function(p) { return p.pointLocator.siPrefix; };

        pointListColumnHeaders[pointListColumnHeaders.length] = "<fmt:message key='dsEdit.mbus.exponent'/>";
        pointListColumnFunctions[pointListColumnFunctions.length] = function(p) { return p.pointLocator.exponent; };

        pointListColumnHeaders[pointListColumnHeaders.length] = "<fmt:message key='dsEdit.mbus.vifeTypes'/>";
        pointListColumnFunctions[pointListColumnFunctions.length] = function(p) { return p.pointLocator.vifeTypess; };

        pointListColumnHeaders[pointListColumnHeaders.length] = "<fmt:message key='dsEdit.mbus.vifeLabels'/>";
        pointListColumnFunctions[pointListColumnFunctions.length] = function(p) { return p.pointLocator.vifeLabels; };

    }

    function addPointImpl(indicies) {
        DataSourceEditDwr.addMBusPoint(indicies.addressing, indicies.deviceIndex, indicies.rsIndex, indicies.dbIndex, editPointCB);
    }

    function editPointCBImpl(locator) {
        $set("addressing", locator.addressing);
        $set("addressHex", locator.addressHex);
        $set("identNumber", locator.identNumber);
        $set("medium", locator.medium);
        $set("manufacturer", locator.manufacturer);
        $set("versionHex", locator.versionHex);
        $set("responseFrame", locator.responseFrame);
        $set("difCode", locator.difCode);
        $set("functionField", locator.functionField);
        $set("deviceUnit", locator.deviceUnit);
        $set("tariff", locator.tariff);
        $set("storageNumber", locator.storageNumber);
        $set("vifType", locator.vifType);
        $set("vifLabel", locator.vifLabel);
        $set("unitOfMeasurement", locator.unitOfMeasurement);
        $set("siPrefix", locator.siPrefix);
        $set("exponent", locator.exponent);
        $set("vifeTypes", locator.vifeTypes);
        $set("vifeLabels", locator.vifeLabels);
        if (true) {
            show("pointSaveImg");
        } else {
            // Didn't find the device.
            hide("pointSaveImg");
        }
    }

    function savePointImpl(locator) {
        locator.addressing = $get("addressing");
        locator.addressHex = $get("addressHex");
        locator.identNumber = $get("identNumber");
        locator.medium = $get("medium");
        locator.manufacturer = $get("manufacturer");
        locator.versionHex = $get("versionHex");
        locator.responseFrame = $get("responseFrame");
        locator.difCode = $get("difCode");
        locator.functionField = $get("functionField");
        locator.deviceUnit = $get("deviceUnit");
        locator.tariff = $get("tariff");
        locator.storageNumber = $get("storageNumber");
        locator.vifType = $get("vifType");
        locator.vifLabel = $get("vifLabel");
        locator.unitOfMeasurement = $get("unitOfMeasurement");
        locator.siPrefix = $get("siPrefix");
        locator.exponent = $get("exponent");
        locator.vifeTypess = $get("vifeTypess");
        locator.vifeLabels = $get("vifeLabels");

        DataSourceEditDwr.saveMBusPointLocator(currentPoint.id, $get("xid"), $get("name"), $get("deviceName"), locator, savePointCB);
    }

    function addressChanged() {
        deviceInfo = getElement(networkInfo, $get("addressHex"), "addressString");
        dwr.util.addOptions("id", "description");
    }

    //Apl neu
    function updateModemOrDirect() {
        if($get("useModemOrDirectConnection") == "SERIAL_AT_MODEM") {
            document.getElementById("phonenumber").disabled=false;
        } else {
            document.getElementById("phonenumber").disabled=true;
        }
    }

    function addressingChanged() {
        setDisabled("firstPrimaryAddress", $get("addressingType") != "PRIMARY");
        setDisabled("lastPrimaryAddress", $get("addressingType") != "PRIMARY");
    }

</script>

<c:set var="dsDesc"><fmt:message key="dsEdit.mbus.desc"/></c:set>
<c:set var="dsHelpId" value="mbusDS"/>
<%@ include file="/WEB-INF/jsp/dataSourceEdit/dsHead.jspf" %>
<!-- Disable modem for now-->
<tr>
    <td colspan="2">
        <input type="radio" name="useModemOrDirectConnection" id="useDirectConnection" value="SERIAL_DIRECT" <c:if test="${dataSource.serialDirect}">checked="checked"</c:if> onclick="updateModemOrDirect()" disabled="disabled">
        <label class="formLabelRequired" for="useDirectConnection"><fmt:message key="dsEdit.mbus.useDirectConnection"/></label>
    </td>
</tr>
<tr>
    <td colspan="2">
        <input type="radio" name="useModemOrDirectConnection" id="useModemConnection" value="SERIAL_AT_MODEM" <c:if test="${dataSource.serialAtModem}"> checked="checked"</c:if> onclick="updateModemOrDirect()" disabled="disabled">
        <label class="formLabelRequired" for="useModemConnection"><fmt:message key="dsEdit.mbus.useModemConnection"/></label>
    </td>
</tr>
<tr>
    <td class="formLabelRequired"><fmt:message key="dsEdit.mbus.phonenumber"/></td>
    <td class="formField"><input type="text" id="phonenumber" value="${dataSource.phonenumber}" <c:if test="${dataSource.serialDirect}">disabled="disabled"</c:if>/></td>
</tr>

<%@ include file="/WEB-INF/jsp/dataSourceEdit/editSerialSettings.jsp" %>

<tr>
    <td class="formLabelRequired"><fmt:message key="dsEdit.updatePeriod"/></td>
    <td class="formField">
        <input type="text" id="updatePeriods" value="${dataSource.updatePeriods}" class="formShort"/>
        <sst:select id="updatePeriodType" value="${dataSource.updatePeriodType}">
            <tag:timePeriodOptions sst="true" s="true" min="true" h="true" d="true" w="true" mon="true"/>
        </sst:select>
    </td>
</tr>

</table>
<tag:dsEvents/>
</div>
</td>

<td valign="top">
    <div class="borderDiv marB">
        <table>
            <tr><td colspan="2" class="smallTitle"><fmt:message key="dsEdit.mbus.search"/></td></tr>
            <tr>
            <tr>
                <td colspan="6">
                    <input type="radio" name="addressingType" id="usePrimnaryAddressing" value="PRIMARY" checked="checked" onclick="addressingChanged()">
                    <label class="formLabelRequired" for="usePrimnaryAddressing"><fmt:message key="dsEdit.mbus.usePrimaryAddressing"/></label>
                    <span class="formLabelRequired"><fmt:message key="dsEdit.mbus.firstHexAddress"/></span>
                    <span class="formField"><input type="text" id="firstPrimaryAddress" value="00"/></span>
                    <span class="formLabelRequired"><fmt:message key="dsEdit.mbus.lastHexAddress"/></span>
                    <span class="formField"><input type="text" id="lastPrimaryAddress" value="FA"/></span>
                </td>
            </tr>
            <tr>
                <td colspan="2">
                    <input type="radio" name="addressingType" id="useSecondaryAddressing" value="SECONDARY" onclick="addressingChanged()">
                    <label class="formLabelRequired" for="useSecondaryAddressing"><fmt:message key="dsEdit.mbus.useSecondaryAddressing"/></label>
                </td>
            </tr>
            <td colspan="2" align="center">
                <input id="searchBtn" type="button" value="<fmt:message key="dsEdit.mbus.search"/>" onclick="search();"/>
                <input id="cancelSearchBtn" type="button" value="<fmt:message key="common.cancel"/>" onclick="cancelSearch();"/>
            </td>
            </tr>

            <tr><td colspan="2" id="searchMessage" class="formError"></td></tr>

            <tr>
                <td colspan="2">
                    <table cellspacing="1">
                        <tr class="rowHeader">
                            <td><fmt:message key="dsEdit.mbus.addressHex"/></td>
                            <td><fmt:message key="dsEdit.mbus.identNumber"/></td>
                            <td><fmt:message key="dsEdit.mbus.medium"/></td>
                            <td><fmt:message key="dsEdit.mbus.manufacturer"/></td>
                            <td><fmt:message key="dsEdit.mbus.versionHex"/></td>
                        </tr>
                        <tbody id="mbusDevices"></tbody>
                    </table>
                </td>
            </tr>

            <tbody id="responseFrames">
                <tr><td colspan="2"><div dojoType="Tree" toggle="wipe" widgetId="responseFramesTree"></div></td></tr>
            </tbody>

            <%@ include file="/WEB-INF/jsp/dataSourceEdit/dsFoot.jspf" %>


            <tag:pointList pointHelpId="mbusPP">

                <tr>
                    <td class="formLabelRequired"><fmt:message key="dsEdit.mbus.addressing"/></td>
                    <td class="formField"><input type="text" id="addressing" disabled="disabled"/></td>
                </tr>
                <tr>
                    <td class="formLabelRequired"><fmt:message key="dsEdit.mbus.addressHex"/></td>
                    <td class="formField"><input type="text" id="addressHex" disabled="disabled"/></td>
                </tr>

                <tr>
                    <td class="formLabelRequired"><fmt:message key="dsEdit.mbus.identNumber"/></td>
                    <td class="formField"><input type="text" id="identNumber" disabled="disabled"/></td>
                </tr>

                <tr>
                    <td class="formLabelRequired"><fmt:message key="dsEdit.mbus.medium"/></td>
                    <td class="formField"><input type="text" id="medium" disabled="disabled"/></td>
                </tr>

                <tr>
                    <td class="formLabelRequired"><fmt:message key="dsEdit.mbus.manufacturer"/></td>
                    <td class="formField"><input type="text" id="manufacturer" disabled="disabled"/></td>
                </tr>

                <tr>
                    <td class="formLabelRequired"><fmt:message key="dsEdit.mbus.versionHex"/></td>
                    <td class="formField"><input type="text" id="versionHex" disabled="disabled"/></td>
                </tr>

                <tr>
                    <td class="formLabelRequired"><fmt:message key="dsEdit.mbus.responseFrame"/></td>
                    <td class="formField"><input type="text" id="responseFrame" disabled="disabled"/></td>
                </tr>

                <tr>
                    <td class="formLabelRequired"><fmt:message key="dsEdit.mbus.difCode"/></td>
                    <td class="formField"><input type="text" id="difCode" disabled="disabled"/></td>
                </tr>

                <tr>
                    <td class="formLabelRequired"><fmt:message key="dsEdit.mbus.functionField"/></td>
                    <td class="formField"><input type="text" id="functionField" disabled="disabled"/></td>
                </tr>

                <tr>
                    <td class="formLabelRequired"><fmt:message key="dsEdit.mbus.deviceUnit"/></td>
                    <td class="formField"><input type="text" id="deviceUnit" disabled="disabled"/></td>
                </tr>

                <tr>
                    <td class="formLabelRequired"><fmt:message key="dsEdit.mbus.tariff"/></td>
                    <td class="formField"><input type="text" id="tariff" disabled="disabled"/></td>
                </tr>

                <tr>
                    <td class="formLabelRequired"><fmt:message key="dsEdit.mbus.storageNumber"/></td>
                    <td class="formField"><input type="text" id="storageNumber" disabled="disabled"/></td>
                </tr>

                <tr>
                    <td class="formLabelRequired"><fmt:message key="dsEdit.mbus.vifType"/></td>
                    <td class="formField"><input type="text" id="vifType" disabled="disabled"/></td>
                </tr>

                <tr>
                    <td class="formLabelRequired"><fmt:message key="dsEdit.mbus.vifLabel"/></td>
                    <td class="formField"><input type="text" id="vifLabel" disabled="disabled"/></td>
                </tr>

                <tr>
                    <td class="formLabelRequired"><fmt:message key="dsEdit.mbus.unitOfMeasurement"/></td>
                    <td class="formField"><input type="text" id="unitOfMeasurement" disabled="disabled"/></td>
                </tr>

                <tr>
                    <td class="formLabelRequired"><fmt:message key="dsEdit.mbus.siPrefix"/></td>
                    <td class="formField"><input type="text" id="siPrefix" disabled="disabled"/></td>
                </tr>

                <tr>
                    <td class="formLabelRequired"><fmt:message key="dsEdit.mbus.exponent"/></td>
                    <td class="formField"><input type="text" id="exponent" disabled="disabled"/></td>
                </tr>

                <tr>
                    <td class="formLabelRequired"><fmt:message key="dsEdit.mbus.vifeTypes"/></td>
                    <td class="formField"><input type="text" id="vifeTypes" disabled="disabled"/></td>
                </tr>
                <tr>
                    <td class="formLabelRequired"><fmt:message key="dsEdit.mbus.vifeLabels"/></td>
                    <td class="formField"><input type="text" id="vifeLabels" disabled="disabled"/></td>
                </tr>

            </tag:pointList>
