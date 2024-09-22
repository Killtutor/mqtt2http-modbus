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
<div id="staticEditorPopup" style="display:none;left:0px;top:0px;" class="windowDiv">
  <table cellpadding="0" cellspacing="0"><tr><td>
    <table width="100%">
      <tr>
        <td>
          <tag:img png="plugin_edit" title="viewEdit.static.editor" style="display:inline;"/>
          <span class="copyTitle"><fmt:message key='viewEdit.static.editor'/></span>
        </td>
        <td align="right">
          <tag:img png="save" onclick="staticEditor.save()" title="common.save" style="display:inline;"/>&nbsp;
          <tag:img png="cross" onclick="staticEditor.close()" title="common.close" style="display:inline;"/>
        </td>
      </tr>
    </table>
    <table>
      <tr>
        <td class="formField"><textarea id="staticPointContent" rows="10" cols="70"></textarea></td>
      </tr>
      <tr>
        <td><span class="copyTitle" id="staticNote"></span></td>
      </tr>
    </table>
  </td></tr></table>

  <script type="text/javascript">
    function StaticEditor() {
        this.componentId = null;

        this.open = function(compId) {
            staticEditor.componentId = compId;

            ViewDwr.getViewComponent(compId, function(comp) {
                // Update the data in the form.
                staticEditor.component = comp;

                if(comp.defName=='compoundScript'){
                    $set("staticPointContent", comp.staticContent);
                    $set("staticNote", "<fmt:message key='viewEdit.static.dynContent'/><b> " + "c" + comp.id + "DynContent</b>");
                }else if(comp.defName=='htmlMeta'){
                    $set("staticPointContent", comp.htmlContent);
                    $set("staticNote", "<fmt:message key='viewEdit.static.dynContent'/><b> " + "c" + comp.id + "DynContent</b>");
                }else{
                    $set("staticPointContent", comp.content);
                    $set("staticNote", '');
                }

                show("staticEditorPopup");
            });

            positionEditor(compId, "staticEditorPopup");
        };

        this.close = function() {
            hide("staticEditorPopup");
        };

        this.save = function() {
            if(staticEditor.component.defName == "html")
                ViewDwr.saveHtmlComponent(staticEditor.componentId, $get("staticPointContent"), function() {
                    staticEditor.close();
                    updateHtmlComponentContent("c"+ staticEditor.componentId, $get("staticPointContent"));
                });
            if(staticEditor.component.defName == "javascript")
                ViewDwr.saveJavascriptComponent(staticEditor.componentId, $get("staticPointContent"), function() {
                    staticEditor.close();
                    mango.view.updateJavascriptComponentContent("c"+ staticEditor.componentId, $get("staticPointContent"));
                });
            if(staticEditor.component.defName == "compoundScript")
                ViewDwr.saveCompoundScriptStaticContent(staticEditor.componentId, $get("staticPointContent"), function() {
                    staticEditor.close();
                    updateCompoundScriptStaticContent(staticEditor.componentId, $get("staticPointContent"));
                });
            if(staticEditor.component.defName == "htmlMeta")
                ViewDwr.saveMetaHtmlContent(staticEditor.componentId, $get("staticPointContent"), function() {
                    staticEditor.close();
                    updateHtmlMetaStaticContent(staticEditor.componentId, $get("staticPointContent"));
                });
        };
    }
    var staticEditor = new StaticEditor();
  </script>
</div>