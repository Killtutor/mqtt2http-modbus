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
<tag:page dwr="PointHierarchyDwr" onload="init">
<jsp:attribute name="subtitle">
  <fmt:message key="header.pointHierarchy"/>
</jsp:attribute>
<jsp:body>
  <script type="text/javascript">
    var newFolderId=1;

    require([
        "dojo/store/Memory", "dojo/store/Observable", "dijit/tree/ObjectStoreModel", "dijit/Tree", "dijit/tree/dndSource", "dojo/aspect", "dijit/registry",
        "dijit/form/TextBox", "dijit/Menu", "dijit/MenuItem", "dojo/query!css2", "dojo/domReady!"
    ], function(Memory, Observable, ObjectStoreModel, Tree, dndSource, aspect, registry, TextBox, Menu, MenuItem){
        // Store
        pointHierarchyStore = new Memory({
            data: [
                { id: "root", name:'root', isFolder: true},
                { id: "f0", name:'<fmt:message key="pointHierarchy.dataPoints"/>', isFolder: true, parent: 'root'}
            ],
            getChildren: function(parentItem){
                return this.query({parent: parentItem.id});
            }
        });
        pointHierarchyStore = new Observable(pointHierarchyStore);

        // DnD
        aspect.around(pointHierarchyStore, "put", function(originalPut){
            return function(item, options){
                    if(options && options.parent){
                        if(!options.parent.isFolder)
                            options.parent = pointHierarchyStore.get(options.parent.parent);
                        item.parent = options.parent.id;
                    }
                    return originalPut.call(pointHierarchyStore, item, options);
                }
        });

        // Model
        var pointHierarchyModel = new ObjectStoreModel({
            store: pointHierarchyStore,
            query: {id: "root"},
            mayHaveChildren: function(item){
                return item.isFolder;
            }
        });

        // Tree
        var tree = new Tree({
            model: pointHierarchyModel,
            showRoot: false,
            dndController: dndSource,
            checkItemAcceptance : function(node, source, position){
                var target = registry.getEnclosingWidget(node).item;
                if(target){
                    var result = true;
                    source.forInSelectedItems(function(item){
                        if(target.isFolder){
                            if(item.data.item.parent == target.id)
                                result = false;
                        }else{
                            if(item.data.item.parent == target.parent)
                                result = false;
                        }
                    });
                    return result;
                }
                return false;
            },
            getIconStyle: function(item, opened){
                if(item && !item.isFolder)
                    return {backgroundImage: "url('images/icon_comp.png')"};
                else
                    return {backgroundImage: "url('images/folder_brick.png')"};
            },
            getRowClass: function(item, opened){
                if(!item || item.isFolder)
                    if(item.id=="f0"){
                        return "rootMenu";
                    }else{
                        return "folderMenu";
                    }
            },
            onDblClick: function(item, node, evt){
                this.startEdit(item,node);
            },
            onKeyPress: function(event){
                var item = this.lastFocused.item;
                var node = this.lastFocused;
                if(event.keyCode == dojo.keys.F2)
                    this.startEdit(item, node);
                if(event.keyCode == dojo.keys.DELETE)
                    if(item.isFolder && item.id !="f0")
                        deleteFolder(item);
            },
            startEdit: function(item, node){
                if(item.isFolder && item.id !="f0"){
                    node.labelNode.style.display="none";
                    var textBox = new TextBox({
                        name: "editLabel",
                        value: item.name,
                        style: {
                            width: "150px",
                            marginLeft: "4px",
                            marginRight: "4px"
                        },
                        close: function(){
                            this.destroy();
                            node.labelNode.style.display="";
                            node.focusNode = node.labelNode;
                            node.focus();
                            dojo.addClass(node.domNode.firstChild, "folderMenu");
                        },
                        onFocus: function (){
                            this.textbox.selectionStart = 0;
                            this.textbox.selectionEnd = this.value.length;
                        },
                        onBlur: function(){
                            item.name = this.displayedValue;
                            pointHierarchyStore.put(item);
                            this.close();
                        },
                        onKeyUp: function(event){
                            if(event.keyCode==dojo.keys.ENTER)
                                this.onBlur();
                            if(event.keyCode==dojo.keys.ESCAPE)
                                this.close();
                            // Stops the propagation to the Tree
                            event.stopPropagation();
                        },
                        onKeyDown: function(event){
                            if(event.keyCode==dojo.keys.ESCAPE)
                                event.returnValue=false;        // Avoid the ESC event for Opera Browser.
                        event.stopPropagation();
                        },
                        onDblClick: function(event){ event.stopPropagation();},
                        onMouseDown: function(event){ event.stopPropagation();} //DnD
                    });
                    dojo.removeClass(node.domNode.firstChild, "folderMenu");
                    textBox.placeAt(node.labelNode, "before");
                    node.focusNode = textBox.focusNode;
                    node.focus();
                }
            },
            getNodeByDomId: function(nodeId){
                var items = this.model.store.data;
                for(i=0;i<items.length;i++){
                    node = this._itemNodesMap[items[i].id];
                    if(node)
                        if(node[0].id == nodeId)
                            return node[0];
                }
            }
        });
        tree.placeAt(byId("treeDiv"));
        tree.startup();

        var rootMenu = new Menu({targetNodeIds: [tree.domNode.id], selector : ".rootMenu"});
        rootMenu.addChild(new MenuItem({label: "<fmt:message key='common.add'/>", iconClass: "addFolder", onClick: function(evt){newFolder("f0");}}));

        var folderMenu = new Menu({targetNodeIds: [tree.domNode.id], selector : ".folderMenu"});

        // Menu children
        // Add Folder
        folderMenu.addChild(new MenuItem({label: "<fmt:message key='common.add'/>", iconClass: "addFolder", onClick: function(evt){
                var node = tree.getNodeByDomId(folderMenu.currentTarget.parentElement.id);
                // Force the focus only to the row under the menu
                tree.focusNode(node);
                tree._expandNode(node);
                newFolder(node.item.id);
            }
        }));
        // Edit Folder
        folderMenu.addChild(new MenuItem({label: "<fmt:message key='common.edit'/>", iconClass: "editFolder", onClick: function(evt){
                var node = tree.getNodeByDomId(folderMenu.currentTarget.parentElement.id);
                // Force the focus only to the row under the menu
                tree.focusNode(node);
                tree.startEdit(node.item, node);
                newFolder(node.item.id);
            }
        }));
        // Delete Folder
        folderMenu.addChild(new MenuItem({label: "<fmt:message key='common.delete'/>", iconClass: "deleteFolder", onClick: function(evt){
                var node = tree.getNodeByDomId(folderMenu.currentTarget.parentElement.id);
                // Force the focus only to the row under the menu
                tree.focusNode(node);
                deleteFolder(node.item);
            }
        }));
    });

    function init() {
        PointHierarchyDwr.getPointHierarchy(initCB);
        setErrorMessage();
    }

    function initCB(rootFolder) {
        var i;
        for (i=0; i<rootFolder.subfolders.length; i++)
            addFolder(rootFolder.subfolders[i], 0);

        for (i=0; i<rootFolder.points.length; i++)
            addPoint(rootFolder.points[i], 0);

        hide("loadingImg");
        show("treeDiv");
    }

    function addFolder(folder, parentId) {
        var i;
        var folderNode = {id: "f" + folder.id, dbId: folder.id, isFolder: true, name: folder.name, parent: "f" + parentId};
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
        var pointNode = {id: "p" + point.key, dbId: point.key, isFolder: false, name: point.value, parent: "f" + parentId};
        pointHierarchyStore.add(pointNode);
    }

    function newFolder(parentId) {
        setErrorMessage();
        var folder = {
            id: "n" + newFolderId++,
            dbId: <c:out value="<%= Common.NEW_ID %>"/>,
            isFolder: true,
            name: "<fmt:message key="pointHierarchy.defaultName"/>",
            parent: parentId
        };
        pointHierarchyStore.add(folder);
    }

    function save() {
        startImageFader(byId("saveImg"));
        setErrorMessage();
        var rootFolder = {id: 0, name: "root", subfolders: new Array(), points: new Array()};
        gatherTreeData("f0", rootFolder);
        PointHierarchyDwr.savePointHierarchy(rootFolder, function(){
            setErrorMessage("<fmt:message key="pointHierarchy.saved"/>");
            stopImageFader(byId("saveImg"));
        });
    }

    function gatherTreeData(folderId, pointFolder) {
        var children = pointHierarchyStore.getChildren(pointHierarchyStore.get(folderId));
        for(var i=0; i<children.length; i++){
            if(children[i].isFolder){
                var child = {id: children[i].dbId, name: children[i].name, subfolders: new Array(), points: new Array()};
                pointFolder.subfolders[pointFolder.subfolders.length] = child;
                gatherTreeData(children[i].id, child);
            }else{
                var child = {key: children[i].dbId, value: children[i].name};
                pointFolder.points[pointFolder.points.length] = child;
            }
        }
    }

    function deleteFolder(item) {
        setErrorMessage();
        var children = pointHierarchyStore.getChildren(item);
        if (children.length > 0) {
            if (!confirm("<fmt:message key="pointHierarchy.deleteConfirm"/>"))
                return;
        }

        for(var i=0; i<children.length; i++){
            children[i].parent = item.parent;
            pointHierarchyStore.put(children[i]);
        }
        pointHierarchyStore.remove(item.id);
    }

    function setErrorMessage(message) {
        if (!message)
            hide("errorMessage");
        else {
            byId("errorMessage").innerHTML = message;
            show("errorMessage");
        }
    }
  </script>
  <style>
    .addFolder {
        background-image: url("images/folder_add.png");
        width: 16px;
        height: 16px;
    }
    .editFolder {
        background-image: url("images/folder_edit.png");
        width: 16px;
        height: 16px;
    }
    .deleteFolder {
        background-image: url("images/folder_delete.png");
        width: 16px;
        height: 16px;
    }
  </style>
  <table>
    <tr>
      <td valign="top">
        <div class="borderDivPadded">
          <table width="100%">
            <tr>
              <td>
                <span class="smallTitle"><fmt:message key="pointHierarchy.hierarchy"/></span>
                <tag:help id="pointHierarchy"/>
              </td>
              <td align="right">
                <tag:img id="saveImg" png="save" title="common.save" onclick="save()"/>
              </td>
            </tr>
            <tr><td class="formError" id="errorMessage"></td></tr>
          </table>
          <tag:img png="hourglass" id="loadingImg"/>
          <div id="treeDiv" style="display:none;"></div>
        </div>
      </td>
    </tr>
  </table>
</jsp:body>
</tag:page>