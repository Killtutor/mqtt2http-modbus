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
<%@page import="com.serotonin.mango.view.ShareUser"%>
<tag:page dwr="WatchListDwr" js="view" onload="init">
<jsp:attribute name="subtitle">
  <fmt:message key="header.watchlist"/>
</jsp:attribute>
<jsp:attribute name="styles">
<style>
    .watchListAttr {
        min-width:600px;
    }
    .rowIcons img {
        padding-right: 3px;
    }
</style>
</jsp:attribute>

<jsp:body>
<script type="text/javascript">
    require(["dojo/parser", "dijit/layout/ContentPane", "dijit/layout/BorderContainer"]);

    require([
        "dojo/store/Memory", "dojo/store/Observable", "dijit/tree/ObjectStoreModel", "dijit/Tree", "dijit/tree/dndSource", "dojo/aspect", "dijit/registry", "dojo/_base/declare", "dojo/domReady!"
    ], function(Memory, Observable, ObjectStoreModel, Tree, dndSource, aspect, registry, declare){
        // Store
        pointHierarchyStore = new Memory({
            data: [
                { id: "root", label:'root', isFolder: true},
                { id: "f0", label:'<fmt:message key="pointHierarchy.dataPoints"/>', isFolder: true, parent: 'root'}
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
            labelAttr: "label",
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
            getIconStyle: function(item, opened){
                if(item && !item.isFolder)
                    return {backgroundImage: "url('images/icon_comp.png')"};
                else
                    return {backgroundImage: "url('images/folder_brick.png')"};
            },
            onClick: function(item, node, evt){
                if(!item.isFolder)
                    addToWatchList(item.dbId, item.name);
            },
            _createTreeNode: function(args){
                var treeNode = new MyTreeNode(args);
                return treeNode;
            },
            onOpen: function(item, node){
                children = pointHierarchyStore.getChildren(item);
                for(i=0;i<children.length;i++){
                    if(!children[i].isFolder){
                        var ListNode = byId(children[i].id);
                        if(ListNode){
                            togglePointTreeIcon(children[i].dbId, false);
                        }else{
                            togglePointTreeIcon(children[i].dbId, true);
                        }
                    }
                }
            }
        });

        tree.placeAt(byId("treeDiv"));
        tree.startup();
    });

    mango.view.initWatchlist();
    mango.share.dwr = WatchListDwr;
    var owner;
    var wlOwner;
    var watchlistChangeId = 0;

    function init() {
        WatchListDwr.init(function(data) {
            mango.share.users = data.shareUsers;

            <c:if test="${sessionUser.superAdmin}">
            dwr.util.addOptions("ownerList", data.allUsers, "id", "username");
            </c:if>

            // Add default points.
            displayWatchList(data.selectedWatchList);
            maybeDisplayDeleteImg();

            hide("loadingListImg");
        });
        WatchListDwr.getDateRangeDefaults(<c:out value="<%= Common.TimePeriods.DAYS %>"/>, 1, function(data) { setDateRange(data); });
        getPointFolder();
    }

    function getPointFolder(){
        WatchListDwr.getPointFolder(function(rootFolder) {
            // Create the point tree.
            var i;
            for (i=0; i<rootFolder.subfolders.length; i++)
                addFolder(rootFolder.subfolders[i], rootFolder.id);

            for (i=0; i<rootFolder.points.length; i++)
                addPoint(rootFolder.points[i], rootFolder.id);

            hide("loadingImg");
            show("treeDiv");
        });
    }

    function addFolder(folder, parentId) {
        var i;
        var folderNode = {id: "f" + folder.id, dbId: folder.id, isFolder: true, label: folder.name, parent: "f" + parentId};
        pointHierarchyStore.add(folderNode);

        if (folder.subfolders) {
            for (i=0; i<folder.subfolders.length; i++)
                addFolder(folder.subfolders[i], folder.id);
        }
        if (folder.points) {
            for (i=0; i<folder.points.length; i++)
                addPoint(folder.points[i], folder.id);
        }
    }

    function addPoint(point, parentId) {
        var pointNode = {id: "p" + point.key, dbId: point.key, isFolder: false,
                        label: point.value + "<img src='images/bullet_go.png' id='ph"+ point.key +"Image' title='<fmt:message key="watchlist.addToWatchlist"/>'/>",
                        name: point.value,
                        parent: "f" + parentId};
        pointHierarchyStore.add(pointNode);
    }

    function displayWatchList(data) {
        wlOwner=data.owner;

        if (!data.points)
            // Couldn't find the watchlist. Reload the page
            window.location.reload();

        var points = data.points;
        owner = data.access == <c:out value="<%= ShareUser.ACCESS_OWNER %>"/>;

        // Add the new rows.
        for (var i=0; i<points.length; i++) {
            addToWatchListImpl(points[i].key, points[i].value);
        }

        fixRowFormatting();
        mango.view.watchList.reset();

        var select = byId("watchListSelect");
        var txt = byId("newWatchListName");
        $set(txt, select.options[select.selectedIndex].text);

        // Display controls based on access
        var iconSrc;
        if (owner) {
            show("wlEditDiv", "inline");
            show("usersEditDiv", "inline");

            // Set the share users.
            mango.share.writeSharedUsers(data.users);
            iconSrc = "images/bullet_go.png";

            <c:if test="${sessionUser.superAdmin}">
            $set("ownerList", data.owner);
            </c:if>
        } else {
            hide("wlEditDiv");
            hide("usersEditDiv");
            iconSrc = "images/bullet_key.png";
        }

        var icons = getElementsByMangoName(byId("treeDiv"), "pointTreeIcon");
        for (var i=0; i<icons.length; i++)
            icons[i].src = iconSrc;
    }

    function showWatchListEdit() {
        openLayer("wlEdit");
        byId("newWatchListName").select();
    }

    function saveWatchListName() {
        var name = $get("newWatchListName");
        var select = byId("watchListSelect");
        select.options[select.selectedIndex].text = name;
        WatchListDwr.updateWatchListName(name);
        hideLayer("wlEdit");
    }

    function watchListChanged() {
        // Clear the list.
        var rows = getElementsByMangoName(byId("watchListTable"), "watchListRow");
        for (var i=0; i<rows.length; i++)
            removeFromWatchListImpl(rows[i].id.substring(1));

        watchlistChangeId++;
        var id = watchlistChangeId;
        WatchListDwr.setSelectedWatchList($get("watchListSelect"), function(data) {
            if (id == watchlistChangeId)
                displayWatchList(data);
        });
    }

    function addWatchList(copy) {
        var copyId = ${NEW_ID};
        if (copy)
            copyId = $get("watchListSelect");

        WatchListDwr.addNewWatchList(copyId, function(watchListData) {
            var wlselect = byId("watchListSelect");
            wlselect.options[wlselect.options.length] = new Option(watchListData.value, watchListData.key);
            $set(wlselect, watchListData.key);
            watchListChanged();
            maybeDisplayDeleteImg();
        });
    }

    function deleteWatchList() {
        var wlselect = byId("watchListSelect");
        var deleteId = $get(wlselect);
        wlselect.options[wlselect.selectedIndex] = null;

        watchListChanged();
        WatchListDwr.deleteWatchList(deleteId);
        maybeDisplayDeleteImg();
    }

    function maybeDisplayDeleteImg() {
        var wlselect = byId("watchListSelect");
        display("watchListDeleteImg", wlselect.options.length > 1);
    }

    function showWatchListUsers() {
        openLayer("usersEdit");
    }

    function showWatchListOwner() {
        openLayer("ownerEdit");
    }

    function openLayer(nodeId) {
        var nodeDiv = byId(nodeId);
        closeLayers(nodeId);
        var divBounds = getNodeBounds(nodeDiv);
        var ancBounds = getNodeBounds(findRelativeAncestor(nodeDiv));
        nodeDiv.style.left = (ancBounds.w - divBounds.w - 30) +"px";
        showLayer(nodeDiv, true);
    }

    function closeLayers(exclude) {
        if (exclude != "wlEdit")
            hideLayer("wlEdit");
        if (exclude != "usersEdit")
            hideLayer("usersEdit");
        if (exclude != "ownerEdit")
            if(byId("ownerEdit"))
                hideLayer("ownerEdit");
    }


    //
    // Watch list membership
    //
    function addToWatchList(pointId, pointName) {
        // Check if this point is already in the watch list.
        if (byId("p"+ pointId) || !owner)
            return;
        addToWatchListImpl(pointId, pointName);
        WatchListDwr.addToWatchList(pointId, mango.view.watchList.setDataImpl);
        fixRowFormatting();
    }

    var watchListCount = 0;
    function addToWatchListImpl(pointId, pointName) {
        watchListCount++;

        // Add a row for the point by cloning the template row.
        var pointContent = createFromTemplate("p_TEMPLATE_", pointId, "watchListTable");
        pointContent.mangoName = "watchListRow";

        if (owner) {
            show("p"+ pointId +"MoveUp");
            show("p"+ pointId +"MoveDown");
            show("p"+ pointId +"Delete");
        }

        byId("p"+ pointId +"Name").innerHTML = pointName;

        // Disable the element in the point list.
        togglePointTreeIcon(pointId, false);
    }

    function removeFromWatchList(pointId) {
        removeFromWatchListImpl(pointId);
        fixRowFormatting();
        WatchListDwr.removeFromWatchList(pointId);
    }

    function removeFromWatchListImpl(pointId) {
        watchListCount--;
        var pointContent = byId("p"+ pointId);
        var watchListTable = byId("watchListTable");
        watchListTable.removeChild(pointContent);

        // Enable the element in the point list.
        togglePointTreeIcon(pointId, true);
    }

    function togglePointTreeIcon(pointId, enable) {
        var node = byId("ph"+ pointId +"Image");
        if (node) {
            if (enable)
                setOpacity(node, 1);
            else
                setOpacity(node, 0.2);
        }
    }

    //
    // List state updating
    //
    function moveRowDown(pointId) {
        var watchListTable = byId("watchListTable");
        var rows = getElementsByMangoName(watchListTable, "watchListRow");
        var i=0;
        for (; i<rows.length; i++) {
            if (rows[i].id == pointId)
                break;
        }
        if (i < rows.length - 1) {
            if (i == rows.length - 1)
                watchListTable.append(rows[i]);
            else
                watchListTable.insertBefore(rows[i], rows[i+2]);
            WatchListDwr.moveDown(pointId.substring(1));
            fixRowFormatting();
        }
    }

    function moveRowUp(pointId) {
        var watchListTable = byId("watchListTable");
        var rows = getElementsByMangoName(watchListTable, "watchListRow");
        var i=0;
        for (; i<rows.length; i++) {
            if (rows[i].id == pointId)
                break;
        }
        if (i != 0) {
            watchListTable.insertBefore(rows[i], rows[i-1]);
            WatchListDwr.moveUp(pointId.substring(1));
            fixRowFormatting();
        }
    }

    function fixRowFormatting() {
        var rows = getElementsByMangoName(byId("watchListTable"), "watchListRow");
        if (rows.length == 0) {
            show("emptyListMessage");
        }
        else {
            hide("emptyListMessage");
            for (var i=0; i<rows.length; i++) {
                if (i == 0) {
                    hide(rows[i].id +"BreakRow");
                    hide(rows[i].id +"MoveUp");
                }
                else {
                    show(rows[i].id +"BreakRow");
                    if (owner)
                        show(rows[i].id +"MoveUp");
                }

                if (i == rows.length - 1)
                    hide(rows[i].id +"MoveDown");
                else if (owner)
                    show(rows[i].id +"MoveDown");
            }
        }
    }

    function showChart(mangoId, event, source) {
        if (isMouseLeaveOrEnter(event, source)) {
            // Take the data in the chart textarea and put it into the chart layer div
            $set('p'+ mangoId +'ChartLayer', $get('p'+ mangoId +'Chart'));
            showMenu('p'+ mangoId +'ChartLayer', 4, 12);
        }
    }

    function hideChart(mangoId, event, source) {
        if (isMouseLeaveOrEnter(event, source))
            hideLayer('p'+ mangoId +'ChartLayer');
    }

    //
    // Image chart
    //
    function getImageChart() {
        var width = dojo.getContentBox(byId("imageChartDiv")).w - 20;
        startImageFader(byId("imageChartImg"));
        WatchListDwr.getImageChartData(getChartPointList(), $get("fromYear"), $get("fromMonth"), $get("fromDay"),
                $get("fromHour"), $get("fromMinute"), $get("fromSecond"), $get("fromNone"), $get("toYear"),
                $get("toMonth"), $get("toDay"), $get("toHour"), $get("toMinute"), $get("toSecond"), $get("toNone"),
                width, 350, function(data) {
            byId("imageChartDiv").innerHTML = data;
            stopImageFader(byId("imageChartImg"));

            // Make sure the length of the chart doesn't mess up the watch list display. Do async to
            // make sure the rendering gets done.
            //setTimeout(borderContainer.onResize(), 2000);
        });
    }

    function getChartData() {
        var pointIds = getChartPointList();
        if (pointIds.length == 0)
            alert("<fmt:message key="watchlist.noExportables"/>");
        else {
            startImageFader(byId("chartDataImg"));
            WatchListDwr.getChartData(getChartPointList(), $get("fromYear"), $get("fromMonth"), $get("fromDay"),
                    $get("fromHour"), $get("fromMinute"), $get("fromSecond"), $get("fromNone"), $get("toYear"),
                    $get("toMonth"), $get("toDay"), $get("toHour"), $get("toMinute"), $get("toSecond"), $get("toNone"),
                    function(data) {
                stopImageFader(byId("chartDataImg"));
                window.location = "chartExport/watchListData.csv";
            });
        }
    }

    function getChartPointList() {
        var pointIds = $get("chartCB");
        for (var i=pointIds.length-1; i>=0; i--) {
            if (pointIds[i] == "_TEMPLATE_") {
                pointIds.splice(i, 1);
            }
        }
        return pointIds;
    }

    //
    // Create report
    function createReport() {
        window.location = "reports.shtm?wlid="+ $get("watchListSelect");
    }

    function showDetectors(pointId){
      showLayer("p" + pointId + "HourGlass");
      showPointDetectors(pointId, function(){
            hideLayer("p" + pointId + "HourGlass");
      });
    }

    function ownerChanged(){
        if(confirm("<fmt:message key='watchlist.changeOwnerConfirm'/>")){
            var userId = $get("ownerList");
            if (userId)
                WatchListDwr.updateOwner(userId, function(data){
                    if(data)
                        window.location.reload();
                    else
                        alert("<fmt:message key='login.validation.noSuchUser'/>");
                });
        }else{
            $set("ownerList", wlOwner);
        }
      }
</script>
  <table width="100%">
    <tr><td>
      <div data-dojo-type="dijit/layout/BorderContainer" data-dojo-props="design:'sidebar', gutters:true, liveSplitters:true" id="borderContainer" style="width: 100%; height: 480px;">
        <div data-dojo-type="dijit/layout/ContentPane" data-dojo-props="splitter:true, region:'leading'" style="width:25%;padding:2px;">
          <span class="smallTitle"><fmt:message key="watchlist.points"/></span> <tag:help id="watchListPoints"/><br/>
          <img src="images/hourglass.png" id="loadingImg"/>
          <div id="treeDiv" style="display:none;"></div>
        </div>
        <div data-dojo-type="dijit/layout/ContentPane" data-dojo-props="splitter:true, region:'center'" style="overflow:auto; padding:2px 10px 2px 2px;">
          <table cellpadding="0" cellspacing="0" width="100%">
            <tr>
              <td class="smallTitle"><fmt:message key="watchlist.watchlist"/> <tag:help id="watchList"/></td>
              <td align="right">
                <sst:select id="watchListSelect" value="${selectedWatchList}" onchange="watchListChanged()"
                        onmouseover="closeLayers();">
                  <c:forEach items="${watchLists}" var="wl">
                    <sst:option value="${wl.key}">${sst:escapeLessThan(wl.value)}</sst:option>
                  </c:forEach>
                </sst:select>

                <div id="wlEditDiv" style="display:inline;" onmouseover="showWatchListEdit()">
                  <tag:img id="wlEditImg" png="pencil" title="watchlist.editListName"/>
                  <div id="wlEdit" style="visibility:hidden;left:0px;top:15px;" class="labelDiv"
                          onmouseout="hideLayer(this)">
                    <fmt:message key="watchlist.newListName"/><br/>
                    <input type="text" id="newWatchListName"
                            onkeypress="if (event.keyCode==13) byId('saveWatchListNameLink').onclick();"/>
                    <a class="ptr" id="saveWatchListNameLink" onclick="saveWatchListName()"><fmt:message key="common.save"/></a>
                  </div>
                </div>

                <div id="usersEditDiv" style="display:inline;" onmouseover="showWatchListUsers()">
                  <tag:img png="user" title="share.sharing" onmouseover="closeLayers();"/>
                  <div id="usersEdit" style="visibility:hidden;left:0px;top:15px;" class="labelDiv">
                    <tag:sharedUsers doxId="watchListSharing" noUsersKey="share.noWatchlistUsers"
                            closeFunction="hideLayer('usersEdit')"/>
                  </div>
                </div>
                <tag:img png="copy" onclick="addWatchList(true)" title="watchlist.copyList" onmouseover="closeLayers();"/>
                <tag:img png="add" onclick="addWatchList(false)" title="watchlist.addNewList" onmouseover="closeLayers();"/>
                <tag:img png="delete" id="watchListDeleteImg" onclick="deleteWatchList()" title="watchlist.deleteList"
                        style="display:none;" onmouseover="closeLayers();"/>
                <c:if test="${sessionUser.superAdmin}">
                  <div id="ownerEditDiv" style="display:inline;" onmouseover="showWatchListOwner()">
                    <tag:img png="user_suit" title="common.owner" onmouseover="closeLayers();"/>
                    <div id="ownerEdit" style="visibility:hidden;left:0px;top:15px;min-width:150px;" class="labelDiv">
                      <div>
                        <div style="float:left;width:70%">
                          <tag:img png="user_suit" title="share.sharing"/>
                          <span class="smallTitle"><fmt:message key="common.owner"/></span>
                        </div>
                        <div style="float:left;text-align:right;width:30%">
                          <tag:img png="cross" onclick="hideLayer('ownerEdit')" title="common.close" style="display:inline;"/>
                        </div>
                      </div>
                      <div style="clear:left; float:left;">
                        <select id="ownerList" onchange="ownerChanged();"></select>
                      </div>
                    </div>
                  </div>
                </c:if>
                <c:if test="${sessionUser.admin}">
                  <tag:img png="report_add" onclick="createReport()" title="watchlist.createReport" onmouseover="closeLayers();"/>
                </c:if>
              </td>
            </tr>
          </table>
          <div id="watchListDiv" class="watchListAttr">
            <table style="display:none;">
              <tbody id="p_TEMPLATE_">
                <tr id="p_TEMPLATE_BreakRow"><td class="horzSeparator" colspan="6"></td></tr>
                <tr>
                  <td width="1">
                    <table cellpadding="0" cellspacing="0" class="rowIcons">
                      <tr>
                        <td onmouseover="mango.view.showChange('p'+ getMangoId(this) +'Change', 4, 12);"
                                onmouseout="mango.view.hideChange('p'+ getMangoId(this) +'Change');"
                                id="p_TEMPLATE_ChangeMin" style="display:none;"><img alt="" id="p_TEMPLATE_Changing"
                                src="images/icon_edit.png"/><div id="p_TEMPLATE_Change" class="labelDiv"
                                style="visibility:hidden;top:10px;left:1px;" onmouseout="hideLayer(this);">
                          <tag:img png="hourglass" title="common.gettingData"/></div>
                        </td>
                        <td id="p_TEMPLATE_ChartMin" style="display:none;" onmouseover="showChart(getMangoId(this), event, this);"
                                onmouseout="hideChart(getMangoId(this), event, this);"><img alt=""
                                src="images/icon_chart.png"/><div id="p_TEMPLATE_ChartLayer" class="labelDiv"
                                style="visibility:hidden;top:0;left:0;"></div><textarea
                                style="display:none;" id="p_TEMPLATE_Chart"><tag:img png="hourglass"
                                title="common.gettingData"/></textarea>
                        </td>
                        <td id="p_TEMPLATE_pointDetectorsEdit" style="display:none;">
                          <tag:img png="bell" onclick="showDetectors(getMangoId(this))" onmouseover="closeLayers();" title="pointEdit.detectors.eventDetectors"/>
                          <div id="p_TEMPLATE_HourGlass"style="visibility:hidden;" class="labelDiv" ><tag:img png="hourglass" title="common.gettingData"/></div>
                        </td>
                      </tr>
                    </table>
                  </td>
                  <td id="p_TEMPLATE_Name" style="font-weight:bold"></td>
                  <td id="p_TEMPLATE_Value" align="center"><img src="images/hourglass.png"/></td>
                  <td id="p_TEMPLATE_Time" align="center"></td>
                  <td style="width:1px; white-space:nowrap;">
                    <input type="checkbox" name="chartCB" id="p_TEMPLATE_ChartCB" value="_TEMPLATE_" disabled="true"
                            title="<fmt:message key="watchlist.consolidatedChart"/>"/>
                    <tag:img png="icon_comp" title="watchlist.pointDetails" id="p_TEMPLATE_Details"
                            onclick="window.location='data_point_details.shtm?dpid='+ getMangoId(this)"/>
                  </td>
                  <td style="width:1px; white-space:nowrap;" align="right">
                    <tag:img png="arrow_up_thin" id="p_TEMPLATE_MoveUp" title="watchlist.moveUp" style="display:none;"
                            onclick="moveRowUp('p'+ getMangoId(this));"/>
                    <tag:img png="arrow_down_thin"
                            id="p_TEMPLATE_MoveDown" title="watchlist.moveDown" style="display:none;"
                            onclick="moveRowDown('p'+ getMangoId(this));"/>
                    <tag:img id="p_TEMPLATE_Delete" png="bullet_delete" title="watchlist.delete" style="display:none;"
                            onclick="removeFromWatchList(getMangoId(this))"/>
                  </td>
                </tr>
                <tr><td colspan="5" style="padding-left:16px;" id="p_TEMPLATE_Messages"></td></tr>
              </tbody>
            </table>
            <table id="watchListTable" width="100%"></table>
            <div id="loadingListImg" style="padding:10px;text-align:center;">
              <img src="images/hourglass.png"/>
            </div>
            <div id="emptyListMessage" style="color:#888888;padding:10px;text-align:center; display:none;">
              <fmt:message key="watchlist.emptyList"/>
            </div>
          </div>
        </div>
      </div>
    </td></tr>
    <tr><td>
      <div class="borderDiv" style="width: 100%;">
        <table width="100%">
          <tr>
            <td class="smallTitle"><fmt:message key="watchlist.chart"/> <tag:help id="watchListCharts"/></td>
            <td align="right"><tag:dateRange/></td>
            <td>
              <tag:img id="imageChartImg" png="control_play_blue" title="watchlist.imageChartButton"
                      onclick="getImageChart()"/>
              <tag:img id="chartDataImg" png="bullet_down" title="watchlist.chartDataButton"
                      onclick="getChartData()"/>
            </td>
          </tr>
          <tr><td colspan="3" id="imageChartDiv"></td></tr>
        </table>
      </div>
    </td></tr>
  </table>
  <%@ include file="/WEB-INF/jsp/include/pointEventDetectors.jsp" %>
</jsp:body>
</tag:page>
