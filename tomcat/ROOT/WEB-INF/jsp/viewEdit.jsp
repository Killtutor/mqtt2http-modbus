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
<%@page import="com.serotonin.mango.view.ShareUser"%>

<tag:page dwr="ViewDwr" onload="doOnload" js="view">
<jsp:attribute name="subtitle">
  <fmt:message key="header.views"/> (<fmt:message key="common.edit"/>)
</jsp:attribute>
<jsp:body>
  <script type="text/javascript" src="resources/lib/wz_jsgraphics.js"></script>
  <script type="text/javascript">
    mango.view.initEditView();
    mango.share.dwr = ViewDwr;

    dojo.require("dojo.dnd.move");
    function doOnload() {
        <c:forEach items="${form.view.viewComponents}" var="vc">
          <c:set var="compContent"><sst:convert obj="${vc}"/></c:set>
          createViewComponent(${mango:escapeScripts(compContent)}, false);
        </c:forEach>

        ViewDwr.editInit(function(result) {
            mango.share.users = result.shareUsers;
            mango.share.writeSharedUsers(result.viewUsers);
            dwr.util.addOptions(byId("usersList"), result.adminUsers, "id", "username");
            byId("usersList").value= byId("userId").value;
            dwr.util.addOptions(byId("componentList"), result.componentTypes, "key", "value");
            settingsEditor.setPointList(result.pointList);
            compoundEditor.setPointList(result.pointList);
            graphicRendererEditor.setPointList(result.pointList);
            metaEditor.setPointList(result.pointList);
            MiscDwr.notifyLongPoll(mango.longPoll.pollSessionId);
        });
    }

    function changeUser(){
        byId("userId").value = byId("usersList").value;
    }

    function addViewComponent() {
        ViewDwr.addComponent($get("componentList"), function(viewComponent) {
            createViewComponent(viewComponent, true);
            MiscDwr.notifyLongPoll(mango.longPoll.pollSessionId);
        });
    }

    function createViewComponent(viewComponent, center) {
        var content;

        if (viewComponent.defName == 'compoundScript')
            content = byId("compoundScriptTemplate").cloneNode(true);
        else if (viewComponent.pointComponent)
            content = byId("pointTemplate").cloneNode(true);
        else if (viewComponent.defName == 'imageChart')
            content = byId("imageChartTemplate").cloneNode(true);
        else if (viewComponent.defName == 'simpleCompound')
            content = byId("simpleCompoundTemplate").cloneNode(true);
        else if (viewComponent.compoundComponent)
            content = byId("compoundTemplate").cloneNode(true);
        else if (viewComponent.defName == 'html')
            content = byId("htmlTemplate").cloneNode(true);
        else if (viewComponent.defName == 'javascript')
            content = byId("javascriptTemplate").cloneNode(true);
        else if (viewComponent.defName == 'htmlMeta')
            content = byId("htmlMetaTemplate").cloneNode(true);

        configureComponentContent(content, viewComponent, byId("viewContent"), center);

        if (viewComponent.defName == 'simpleCompound') {
            childContent = byId("compoundChildTemplate").cloneNode(true);
            configureComponentContent(childContent, viewComponent.leadComponent, byId("c"+ viewComponent.id +"Content"),
                    false);
        }
        else if (viewComponent.defName == 'imageChart')
            ;
        else if (viewComponent.compoundComponent) {
                // Compound components only have their static content set at page load.
                $set(content.id +"Content", viewComponent.staticContent);

            // Add the child components.
            var childContent;
            for (var i=0; i<viewComponent.childComponents.length; i++) {
                childContent = byId("compoundChildTemplate").cloneNode(true);
                configureComponentContent(childContent, viewComponent.childComponents[i].pointComponent,
                        byId("c"+ viewComponent.id +"Content"), false);
            }
        }
        else if (viewComponent.defName == 'compoundScript')
            updateCompoundScriptStaticContent(viewComponent.id, viewComponent.staticContent);
        else if (viewComponent.defName == 'htmlMeta')
            updateHtmlMetaStaticContent(viewComponent.id, viewComponent.htmlContent);

        addDnD(content.id);
        if (center)
            updateViewComponentLocation(content.id);
    }

    function handleStaticContent(vc) {

        // Static components only get updated at page load and editing.
        var handler =  vc.designTimeHandler;
        if (typeof handler === "string" && handler !== "") {
            var f = window[handler];
            if (typeof f === "function") {
                f(vc);
            }
        }
    }

    function configureComponentContent(content, viewComponent, parent, center) {

        content.id = "c"+ viewComponent.id;
        content.viewComponentId = viewComponent.id;
        updateNodeIds(content, viewComponent.id);
        parent.appendChild(content);

        if (viewComponent.staticComponent) {
            handleStaticContent(viewComponent);
        }

        show(content);

        if (center) {
            // Calculate the location for the new point. For now just put it in the center.
            var bkgd = byId("viewBackground");
            var bkgdBox = dojo.getMarginBox(bkgd);
            var compContentBox = dojo.getMarginBox(content);
            content.style.left = parseInt((bkgdBox.width - compContentBox.width) / 2) +"px";
            content.style.top = parseInt((bkgdBox.height - compContentBox.height) / 2) +"px";
        }
        else {
            content.style.left = viewComponent.x +"px";
            content.style.top = viewComponent.y +"px";
        }
    }

    function updateNodeIds(elem, id) {
        var i;
        for (i=0; i<elem.attributes.length; i++) {
            if (elem.attributes[i].value && elem.attributes[i].value.indexOf("_TEMPLATE_") != -1)
                elem.attributes[i].value = elem.attributes[i].value.replace(/_TEMPLATE_/, id);
        }
        for (var i=0; i<elem.childNodes.length; i++) {
            if (elem.childNodes[i].attributes)
                updateNodeIds(elem.childNodes[i], id);
        }
    }

    function updateHtmlComponent(vc) {
        updateHtmlComponentContent("c" + vc.id, vc.content);
    }

    function updateHtmlComponentContent(id, content) {
        if (!content || content == "")
            if(mango.view.edit.iconize){
                var comp = byId(id);
                comp.savedContent = '<img src="images/html.png" alt=""/>';
            }else
                $set(id + "Content", '<img src="images/html.png" alt=""/>');
        else
            if(mango.view.edit.iconize){
                var comp = byId(id);
                comp.savedContent = content;
            }else
                $set(id + "Content", content);
    }

    function updateJavascriptComponent(vc) {
        mango.view.updateJavascriptComponentContent("c" + vc.id, vc.content);
    }

    function updateCompoundScriptStaticContent(id, newContent) {
        var dynContent = byId("c" + id + "DynContent");
        var staticContent = byId("c" + id + "StaticContent");
        var content = byId("c" + id + "Content");
        var comp = byId("c"+ id);

        if(!comp.savedContent){
            if (dynContent)
                comp.savedContent = dynContent.innerHTML;
            else if(staticContent.innerHTML=="")
                comp.savedContent = content.innerHTML;
        }
        if (newContent){
            if(mango.view.edit.iconize){
                comp.savedStaticContent = newContent;
            }else{
                staticContent.innerHTML=newContent;

                // Check if the dynContent exists in the new staticContent
                dynContent = byId("c" + id + "DynContent");
                if(dynContent){
                    if (comp.savedState)
                        mango.view.setContent(comp.savedState);
                    else
                        dynContent.innerHTML = comp.savedContent;
                    comp.savedContent = null;
                }
                content.innerHTML = "";
            }
        }else{
            if(mango.view.edit.iconize){
                comp.savedStaticContent = "";
            }else{
                staticContent.innerHTML="";
                if (comp.savedState)
                    mango.view.setContent(comp.savedState);
                else
                    content.innerHTML = comp.savedContent;
                comp.savedContent = null;
            }
        }
    }

    function updateHtmlMetaStaticContent(id, newContent) {
        var dynContent = byId("c" + id + "DynContent");
        var staticContent = byId("c" + id + "StaticContent");
        var content = byId("c" + id + "Content");
        var comp = byId("c"+ id);

        if(!comp.savedContent){
            if (dynContent)
                comp.savedContent = dynContent.innerHTML;
            else if(staticContent.innerHTML=="")
                comp.savedContent = content.innerHTML;
        }
        if (newContent){
            if(mango.view.edit.iconize){
                comp.savedStaticContent = newContent;
            }else{
                staticContent.innerHTML=newContent;

                // Check if the dynContent exists in the new staticContent
                dynContent = byId("c" + id + "DynContent");
                if(dynContent){
                    if (comp.savedState)
                        mango.view.setContent(comp.savedState);
                    else
                        dynContent.innerHTML = comp.savedContent;
                    comp.savedContent = null;
                }
                content.innerHTML = "";
            }
        }else{
            if(mango.view.edit.iconize){
                comp.savedStaticContent = "";
            }else{
                staticContent.innerHTML="";
                if (comp.savedState)
                    mango.view.setContent(comp.savedState);
                else
                    content.innerHTML = comp.savedContent;
                comp.savedContent = null;
            }
        }
    }

    function openStaticEditor(viewComponentId) {
        closeEditors();
        staticEditor.open(viewComponentId);
    }

    function openSettingsEditor(cid) {
        closeEditors();
        settingsEditor.open(cid);
    }

    function openMetaEditor(cid) {
        closeEditors();
        metaEditor.open(cid);
    }

    function openGraphicRendererEditor(cid) {
        closeEditors();
        graphicRendererEditor.open(cid);
    }

    function openCompoundEditor(cid) {
        closeEditors();
        compoundEditor.open(cid);
    }

    function positionEditor(compId, editorId) {
        // Position and display the renderer editor.
        var pDim = getNodeBounds(byId("c"+ compId));
        var editDiv = byId(editorId);
        editDiv.style.left = (pDim.x + pDim.w + 20) +"px";
        editDiv.style.top = (pDim.y + 10) +"px";
    }

    function closeEditors() {
        settingsEditor.close();
        graphicRendererEditor.close();
        staticEditor.close();
        compoundEditor.close();
    }

    function updateViewComponentLocation(divId) {
        var div = byId(divId);
        var lt = div.style.left;
        var tp = div.style.top;

        // Remove the 'px's from the positions.
        lt = lt.substring(0, lt.length-2);
        tp = tp.substring(0, tp.length-2);

        // Save the new location.
        ViewDwr.setViewComponentLocation(div.viewComponentId, lt, tp);
    }

    function updateViewComponentChildLocation(parentId, divId, childId) {
        var div = byId(divId);
        var lt = div.style.left;
        var tp = div.style.top;

        // Remove the 'px's from the positions.
        lt = lt.substring(0, lt.length-2);
        tp = tp.substring(0, tp.length-2);

        // Save the new location.
        ViewDwr.setViewComponentChildLocation(parentId, childId, lt, tp);
    }

    function addDnD(divId) {
        var dragSource = new dojo.dnd.move.boxConstrainedMoveable(byId(divId), {
            box: dojo.getContentBox(byId("viewBackground")),
            within: true,
        });

        // Also, create a function to call on drag end to update the point view's location.
        var onDragEnd = function() {updateViewComponentLocation(divId)};
        dojo.connect(dragSource, "onMoveStop", onDragEnd);
    }

    function addPDnD(divId, parentId, childId) {
        var dragSource = new dojo.dnd.move.boxConstrainedMoveable(byId(divId), {
            box: dojo.getContentBox(byId("c" + parentId)),
            within: true
        });

        // Also, create a function to call on drag end to update the point view's location.
        var onDragEnd = function() {updateViewComponentChildLocation(parentId, divId, childId)};
        dojo.connect(dragSource, "onMoveStop", onDragEnd);
    }

    function deleteViewComponent(viewComponentId) {
        closeEditors();
        ViewDwr.deleteViewComponent(viewComponentId);

        var div = byId("c"+ viewComponentId);

        // Disconnect the event handling for drag ends on this guy.
        byId("viewContent").removeChild(div);
        // Only used for javascript components
        var script = byId("c" + viewComponentId + "Script");
        if(script)
            script.parentNode.removeChild(script);
    }

    function getViewComponentId(node) {
        while (!(node.viewComponentId))
            node = node.parentNode;
        return node.viewComponentId;
    }

    function iconizeClicked() {
        ViewDwr.getViewComponentIds(function(ids) {
            var i, comp, content;
            if ($get("iconifyCB")) {
                mango.view.edit.iconize = true;
                for (i=0; i<ids.length; i++) {
                    comp = byId("c"+ ids[i]);
                    content = byId("c"+ ids[i] +"Content");
                    staticContent = byId("c"+ ids[i] +"StaticContent");
                    dynContent = byId("c"+ ids[i] +"DynContent");

                    if (!comp.savedContent){
                        if (dynContent){
                            comp.savedContent = dynContent.innerHTML;
                            dynContent.innerHTML = '';
                        }else
                            comp.savedContent = content.innerHTML;
                        content.innerHTML ='';
                    }
                    if (staticContent){
                        comp.savedStaticContent = staticContent.innerHTML;
                        staticContent.innerHTML = "<img src='images/plugin.png'/>";
                    }else{
                        content.innerHTML = "<img src='images/plugin.png'/>";
                    }
                }
            }
            else {
                mango.view.edit.iconize = false;
                for (i=0; i<ids.length; i++) {
                    comp = byId("c"+ ids[i]);
                    staticContent = byId("c"+ ids[i] +"StaticContent");
                    content = byId("c"+ ids[i] +"Content");

                    if(comp.savedStaticContent){
                        staticContent.innerHTML = comp.savedStaticContent;
                        dynContent = byId("c"+ ids[i] +"DynContent");
                        if(dynContent){
                            if (comp.savedState)
                                mango.view.setContent(comp.savedState);
                            else if (comp.savedContent)
                                dynContent.innerHTML = comp.savedContent;
                            else
                                dynContent.innerHTML = "";
                            comp.savedContent = null;
                        }
                        content.innerHTML = "";
                    }else{
                        if (comp.savedState)
                            mango.view.setContent(comp.savedState);
                        else if (comp.savedContent)
                            content.innerHTML = comp.savedContent;
                        else
                            content.innerHTML = "";
                        comp.savedContent = null;

                        if(staticContent)
                            staticContent.innerHTML="";
                    }
                    comp.savedStaticContent = null;
                    comp.savedState = null;
                }
            }
        });
    }

    var deleteView = function () {
        return confirm("<fmt:message key="viewEdit.deleteConfirm"/>");
    };
  </script>

  <form name="view" action="" method="post" enctype="multipart/form-data">
    <table>
      <tr>
        <td valign="top">
          <div class="borderDiv marR">
            <table>
              <tr>
                <td colspan="3">
                  <tag:img png="icon_view" title="viewEdit.editView"/>
                  <span class="smallTitle"><fmt:message key="viewEdit.viewProperties"/></span>
                  <tag:help id="editingGraphicalViews"/>
                </td>
              </tr>

              <spring:bind path="form.view.name">
                <tr>
                  <td class="formLabelRequired" width="150"><fmt:message key="viewEdit.name"/></td>
                  <td class="formField" width="250">
                    <input type="text" name="view.name" value="${status.value}"/>
                  </td>
                  <td class="formError">${status.errorMessage}</td>
                </tr>
              </spring:bind>
              <spring:bind path="form.view.xid">
                <tr>
                  <td class="formLabelRequired" width="150"><fmt:message key="common.xid"/></td>
                  <td class="formField" width="250">
                    <input type="text" name="view.xid" value="${status.value}"/>
                  </td>
                  <td class="formError">${status.errorMessage}</td>
                </tr>
              </spring:bind>
              <spring:bind path="form.backgroundImageMP">
                <tr>
                  <td class="formLabelRequired"><fmt:message key="viewEdit.background"/></td>
                  <td class="formField">
                    <input type="file" name="backgroundImageMP"/>
                  </td>
                  <td class="formError">${status.errorMessage}</td>
                </tr>
              </spring:bind>
              <tr>
                <td colspan="2" align="center">
                  <input type="submit" name="upload" value="<fmt:message key="viewEdit.upload"/>"/>
                  <input type="submit" name="clearImage" value="<fmt:message key="viewEdit.clearImage"/>"/>
                </td>
                <td></td>
              </tr>
              <spring:bind path="form.view.anonymousAccess">
                <tr>
                  <td class="formLabelRequired" width="150"><fmt:message key="viewEdit.anonymous"/></td>
                  <td class="formField" width="250">
                    <sst:select name="view.anonymousAccess" value="${status.value}">
                      <sst:option value="<%= Integer.toString(ShareUser.ACCESS_NONE) %>"><fmt:message key="common.access.none"/></sst:option>
                      <sst:option value="<%= Integer.toString(ShareUser.ACCESS_READ) %>"><fmt:message key="common.access.read"/></sst:option>
                      <sst:option value="<%= Integer.toString(ShareUser.ACCESS_SET) %>"><fmt:message key="common.access.set"/></sst:option>
                    </sst:select>
                  </td>
                  <td class="formError">${status.errorMessage}</td>
                </tr>
              </spring:bind>
              <spring:bind path="form.view.userId">
                <tr>
                  <td class="formLabelRequired" width="150"><fmt:message key="share.userName"/></td>
                  <td class="formField" width="250">
                  <select id="usersList" onchange="changeUser()"></select>
                  <input style="display:none;" type="text" name="view.userId" id="userId" value="${status.value}"/>
                  </td>
                  <td class="formError">${status.errorMessage}</td>
                </tr>
              </spring:bind>
            </table>
          </div>
        </td>

        <td valign="top">
          <div class="borderDiv">
            <tag:sharedUsers doxId="viewSharing" noUsersKey="share.noViewUsers"/>
          </div>
        </td>
      </tr>
    </table>

    <table>
      <tr>
        <td>
          <fmt:message key="viewEdit.viewComponents"/>:
          <select id="componentList"></select>
          <tag:img png="plugin_add" title="viewEdit.addViewComponent" onclick="addViewComponent()"/>
        </td>
        <td style="width:30px;"></td>
        <td>
          <input type="checkbox" id="iconifyCB" onclick="iconizeClicked();"/>
          <label for="iconifyCB"><fmt:message key="viewEdit.iconify"/></label>
        </td>
      </tr>
    </table>

    <table width="100%" cellspacing="0" cellpadding="0">
      <tr>
        <td>
          <table cellspacing="0" cellpadding="0">
            <tr>
              <td colspan="3">
                <div id="viewContent" class="borderDiv" style="left:0px;top:0px;float:left;
                        padding-right:1px;padding-bottom:1px;">
                  <c:choose>
                    <c:when test="${empty form.view.backgroundFilename}">
                      <img id="viewBackground" src="images/spacer.gif" alt="" width="740" height="500"
                              style="top:1px;left:1px;"/>
                    </c:when>
                    <c:otherwise>
                      <img id="viewBackground" src="${form.view.backgroundFilename}" alt=""
                              style="top:1px;left:1px;"/>
                    </c:otherwise>
                  </c:choose>

                  <%@ include file="/WEB-INF/jsp/include/staticEditor.jsp" %>
                  <%@ include file="/WEB-INF/jsp/include/settingsEditor.jsp" %>
                  <%@ include file="/WEB-INF/jsp/include/graphicRendererEditor.jsp" %>
                  <%@ include file="/WEB-INF/jsp/include/compoundEditor.jsp" %>
                  <%@ include file="/WEB-INF/jsp/include/metaEditor.jsp" %>
                </div>
              </td>
            </tr>

            <tr><td colspan="3">&nbsp;</td></tr>

            <tr>
              <td colspan="2" align="center">
                <input type="submit" name="save" value="<fmt:message key="common.save"/>"/>
                <input type="submit" name="delete" value="<fmt:message key="common.delete"/>" onclick="return deleteView();"/>
                <input type="submit" name="cancel" value="<fmt:message key="common.cancel"/>"/>
              </td>
              <td></td>
            </tr>
          </table>

          <div id="pointTemplate" onmouseover="showLayer('c'+ getViewComponentId(this) +'Controls');"
                  onmouseout="hideLayer('c'+ getViewComponentId(this) +'Controls');"
                  style="position:absolute;left:0px;top:0px;display:none;">
            <div id="c_TEMPLATE_Content"><img src="images/icon_comp.png" alt=""/></div>
            <div id="c_TEMPLATE_Controls" class="controlsDiv">
              <table cellpadding="0" cellspacing="1">
                <tr onmouseover="showMenu('c'+ getViewComponentId(this) +'Info', 16, 0);"
                        onmouseout="hideLayer('c'+ getViewComponentId(this) +'Info');">
                  <td>
                    <img src="images/information.png" alt=""/>
                    <div id="c_TEMPLATE_Info" onmouseout="hideLayer(this);">
                      <tag:img png="hourglass" title="common.gettingData"/>
                    </div>
                  </td>
                </tr>
                <tr><td><tag:img png="plugin_edit" onclick="openSettingsEditor(getViewComponentId(this))"
                        title="viewEdit.editPointView"/></td></tr>
                <tr><td><tag:img png="graphic" onclick="openGraphicRendererEditor(getViewComponentId(this))"
                        title="viewEdit.editGraphicalRenderer"/></td></tr>
                <tr><td><tag:img png="plugin_delete" onclick="deleteViewComponent(getViewComponentId(this))"
                        title="viewEdit.deletePointView"/></td></tr>
              </table>
            </div>
            <div style="position:absolute;left:-16px;top:0px;z-index:1;">
              <div id="c_TEMPLATE_Warning" style="display:none;"
                      onmouseover="showMenu('c'+ getViewComponentId(this) +'Messages', 16, 0);"
                      onmouseout="hideLayer('c'+ getViewComponentId(this) +'Messages');">
                <tag:img png="warn" title="common.warning"/>
                <div id="c_TEMPLATE_Messages" onmouseout="hideLayer(this);" class="controlContent"></div>
              </div>
            </div>
          </div>

          <div id="compoundScriptTemplate" onmouseover="showLayer('c'+ getViewComponentId(this) +'Controls');"
                  onmouseout="hideLayer('c'+ getViewComponentId(this) +'Controls');"
                  style="position:absolute;left:0px;top:0px;display:none;">
            <div id="c_TEMPLATE_Content"><img src="images/icon_comp.png" alt=""/></div>
            <div id="c_TEMPLATE_StaticContent"></div>
            <div id="c_TEMPLATE_Controls" class="controlsDiv">
              <table cellpadding="0" cellspacing="1">
                <tr onmouseover="showMenu('c'+ getViewComponentId(this) +'Info', 16, 0);"
                        onmouseout="hideLayer('c'+ getViewComponentId(this) +'Info');">
                  <td>
                    <img src="images/information.png" alt=""/>
                    <div id="c_TEMPLATE_Info" onmouseout="hideLayer(this);">
                      <tag:img png="hourglass" title="common.gettingData"/>
                    </div>
                  </td>
                </tr>
                <tr><td><tag:img png="plugin_edit" onclick="openSettingsEditor(getViewComponentId(this))"
                        title="viewEdit.editPointView"/></td></tr>
                <tr><td><tag:img png="pencil" onclick="openStaticEditor(getViewComponentId(this))"
                        title="viewEdit.editStaticView"/></td></tr>
                <tr><td><tag:img png="graphic" onclick="openGraphicRendererEditor(getViewComponentId(this))"
                        title="viewEdit.editGraphicalRenderer"/></td></tr>
                <tr><td><tag:img png="plugin_delete" onclick="deleteViewComponent(getViewComponentId(this))"
                        title="viewEdit.deletePointView"/></td></tr>
              </table>
            </div>
            <div style="position:absolute;left:-16px;top:0px;z-index:1;">
              <div id="c_TEMPLATE_Warning" style="display:none;"
                      onmouseover="showMenu('c'+ getViewComponentId(this) +'Messages', 16, 0);"
                      onmouseout="hideLayer('c'+ getViewComponentId(this) +'Messages');">
                <tag:img png="warn" title="common.warning"/>
                <div id="c_TEMPLATE_Messages" onmouseout="hideLayer(this);" class="controlContent"></div>
              </div>
            </div>
          </div>

          <div id="htmlMetaTemplate" onmouseover="showLayer('c'+ getViewComponentId(this) +'Controls');"
                  onmouseout="hideLayer('c'+ getViewComponentId(this) +'Controls');"
                  style="position:absolute;left:0px;top:0px;display:none;">
            <div id="c_TEMPLATE_Content"><img src="images/icon_comp.png" alt=""/></div>
            <div id="c_TEMPLATE_StaticContent"></div>
            <div id="c_TEMPLATE_Controls" class="controlsDiv">
              <table cellpadding="0" cellspacing="1">
                <tr><td><tag:img png="plugin_edit" onclick="openMetaEditor(getViewComponentId(this))"
                        title="viewEdit.editMetaView"/></td></tr>
                <tr><td><tag:img png="pencil" onclick="openStaticEditor(getViewComponentId(this))"
                        title="viewEdit.editStaticView"/></td></tr>
                <tr><td><tag:img png="plugin_delete" onclick="deleteViewComponent(getViewComponentId(this))"
                        title="viewEdit.deletePointView"/></td></tr>
              </table>
            </div>
          </div>

          <div id="htmlTemplate" onmouseover="showLayer('c'+ getViewComponentId(this) +'Controls');"
                  onmouseout="hideLayer('c'+ getViewComponentId(this) +'Controls');"
                  style="position:absolute;left:0px;top:0px;display:none;">
            <div id="c_TEMPLATE_Content"></div>
            <div id="c_TEMPLATE_Controls" class="controlsDiv">
              <table cellpadding="0" cellspacing="1">
                <tr><td><tag:img png="pencil" onclick="openStaticEditor(getViewComponentId(this))"
                        title="viewEdit.editStaticView"/></td></tr>
                <tr><td><tag:img png="html_delete" onclick="deleteViewComponent(getViewComponentId(this))"
                        title="viewEdit.deleteStaticView"/></td></tr>
              </table>
            </div>
          </div>

          <div id="javascriptTemplate" onmouseover="showLayer('c'+ getViewComponentId(this) +'Controls');"
                  onmouseout="hideLayer('c'+ getViewComponentId(this) +'Controls');"
                  style="position:absolute;left:0px;top:0px;display:none;">
            <div id="c_TEMPLATE_Content"></div>
            <div id="c_TEMPLATE_Controls" class="controlsDiv">
              <table cellpadding="0" cellspacing="1">
                <tr><td><tag:img png="pencil" onclick="openStaticEditor(getViewComponentId(this))"
                        title="viewEdit.editStaticView"/></td></tr>
                <tr><td><tag:img png="script_delete" onclick="deleteViewComponent(getViewComponentId(this))"
                        title="viewEdit.deleteStaticView"/></td></tr>
              </table>
            </div>
          </div>

          <div id="imageChartTemplate" onmouseover="showLayer('c'+ getViewComponentId(this) +'Controls');"
                  onmouseout="hideLayer('c'+ getViewComponentId(this) +'Controls');"
                  style="position:absolute;left:0px;top:0px;display:none;">
            <span id="c_TEMPLATE_Content"></span>
            <div id="c_TEMPLATE_Controls" class="controlsDiv">
              <table cellpadding="0" cellspacing="1">
                <tr><td><tag:img png="plugin_edit" onclick="openCompoundEditor(getViewComponentId(this))"
                        title="viewEdit.editPointView"/></td></tr>
                <tr><td><tag:img png="plugin_delete" onclick="deleteViewComponent(getViewComponentId(this))"
                        title="viewEdit.deletePointView"/></td></tr>
              </table>
            </div>
          </div>

          <div id="compoundTemplate" onmouseover="showLayer('c'+ getViewComponentId(this) +'Controls');"
                  onmouseout="hideLayer('c'+ getViewComponentId(this) +'Controls');"
                  style="position:absolute;left:0px;top:0px;display:none;">
            <span id="c_TEMPLATE_Content"></span>
            <div id="c_TEMPLATE_Controls" class="controlsDiv">
              <table cellpadding="0" cellspacing="1">
                <tr onmouseover="showMenu('c'+ getViewComponentId(this) +'Info', 16, 0);"
                        onmouseout="hideLayer('c'+ getViewComponentId(this) +'Info');">
                  <td>
                    <img src="images/information.png" alt=""/>
                    <div id="c_TEMPLATE_Info" onmouseout="hideLayer(this);">
                      <tag:img png="hourglass" title="common.gettingData"/>
                    </div>
                  </td>
                </tr>
                <tr><td><tag:img png="plugin_edit" onclick="openCompoundEditor(getViewComponentId(this))"
                        title="viewEdit.editPointView"/></td></tr>
                <tr><td><tag:img png="plugin_delete" onclick="deleteViewComponent(getViewComponentId(this))"
                        title="viewEdit.deletePointView"/></td></tr>
              </table>
            </div>
            <div id="c_TEMPLATE_ChildComponents"></div>
          </div>

          <div id="simpleCompoundTemplate" onmouseover="showLayer('c'+ getViewComponentId(this) +'Controls');"
                  onmouseout="hideLayer('c'+ getViewComponentId(this) +'Controls');"
                  style="position:absolute;left:0px;top:0px;display:none;">
            <span id="c_TEMPLATE_Content"></span>
            <div id="c_TEMPLATE_Controls" class="controlsDiv">
              <table cellpadding="0" cellspacing="1">
                <tr onmouseover="showMenu('c'+ getViewComponentId(this) +'Info', 16, 0);"
                        onmouseout="hideLayer('c'+ getViewComponentId(this) +'Info');">
                  <td>
                    <img src="images/information.png" alt=""/>
                    <div id="c_TEMPLATE_Info" onmouseout="hideLayer(this);">
                      <tag:img png="hourglass" title="common.gettingData"/>
                    </div>
                  </td>
                </tr>
                <tr><td><tag:img png="plugin_edit" onclick="openCompoundEditor(getViewComponentId(this))"
                        title="viewEdit.editPointView"/></td></tr>
                <tr><td><tag:img png="graphic" onclick="openGraphicRendererEditor(getViewComponentId(this))"
                        title="viewEdit.editGraphicalRenderer"/></td></tr>
                <tr><td><tag:img png="plugin_delete" onclick="deleteViewComponent(getViewComponentId(this))"
                        title="viewEdit.deletePointView"/></td></tr>
              </table>
            </div>
            <div id="c_TEMPLATE_ChildComponents"></div>
          </div>

          <div id="compoundChildTemplate" style="position:absolute;left:0px;top:0px;white-space:nowrap;display:none;">
            <div id="c_TEMPLATE_Content"><img src="images/icon_comp.png" alt=""/></div>
          </div>
        </td>
      </tr>
    </table>
  </form>
</jsp:body>
</tag:page>
