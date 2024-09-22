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
<tag:page dwr="TextGatewayEditDwr">
<jsp:attribute name="subtitle">
  <fmt:message key="header.textGateways"/> (<fmt:message key="common.edit"/>)
</jsp:attribute>
<jsp:body>
  <script type="text/javascript"  >

  var allowedList = new Array();
  var deniedList = new Array();

  dojo.addOnLoad(init);

    function init() {
      TextGatewayEditDwr.init(function(response){

        list = response.data.allowedList;
        for (i=0; i<list.length; i++)
          allowedList[allowedList.length] = {key: list[i].key, value: list[i].value};
        refreshAllowedList();

        list = response.data.deniedList;
        for (i=0; i<list.length; i++)
          deniedList[deniedList.length] = {key: list[i].key, value: list[i].value};
        refreshDeniedList();

        });
    }

    function saveTextGateway() {
      hide("nameMsg");
      hide("message");

      saveTextGatewayImpl($get("name"), $get("xid"));
    }

    function saveTextGatewayCB(response) {
      if (response.hasMessages) {
        for (var i=0; i<response.messages.length; i++)
          showMessage(response.messages[i].contextKey +"Msg", response.messages[i].contextualMessage);
      }
      else
        showMessage("message", "<fmt:message key="textGatewayEdit.saved"/>");
    }

    function addAllowedCode() {
      var name = $get("allowedName");
      var code = $get("allowedCode");

      if (!code || code.trim().length == 0) {
        alert("<fmt:message key="textGatewayEdit.codeRequired"/>");
        return;
      }

      for (var i=0; i<allowedList.length; i++) {
        if (allowedList[i].value == code) {
          alert("<fmt:message key="textGatewayEdit.codeExists"/>: '"+ code +"'");
          return;
        }
      }

      allowedList[allowedList.length] = {key: name, value: code};
      allowedList.sort();
      refreshAllowedList();
    }


    function removeAllowedCode(index) {
      allowedList.splice(index, 1);
      refreshAllowedList();
    }

    function refreshAllowedList() {
      dwr.util.removeAllRows("allowedList");
      if (allowedList.length != 0) {
        dwr.util.addRows("allowedList", allowedList, [
          function(data, options) {
            var result = "";
            if (allowedList.length > 1){
              if (options.rowIndex != 0){
                result = "<img src='images/arrow_up_thin.png' class='ptr' title='<fmt:message key="textGatewayList.moveUp"/>' "+
                         "onclick='allowedRowUp("+ options.rowIndex + ");'/> ";
              }
            }
            return result;
          },
          function(data, options) {
            var result = "";
            if (allowedList.length > 1){
              if (options.rowIndex != allowedList.length -1){
                result += "<img src='images/arrow_down_thin.png' class='ptr' title='<fmt:message key="textGatewayList.moveDown"/>' "+
                          "onclick='allowedRowDown("+ options.rowIndex + ");'/>";
              }
            }
            return result;
          },
          function(data) { return data.key; },
          function(data) { return "(" + data.value + ")"; },
          function(data, options) {
            return "<img src='images/bullet_delete.png' class='ptr' title='<fmt:message key="textGatewayEdit.removeCode"/>' "+
                   "onclick='removeAllowedCode("+ options.rowIndex + ");'/>";
          }
        ], null);
      }
    }

    function addDeniedCode() {
      var name = $get("deniedName");
      var code = $get("deniedCode");

      if (!code || code.trim().length == 0) {
        alert("<fmt:message key="textGatewayEdit.codeRequired"/>");
        return;
      }

      for (var i=0; i<deniedList.length; i++) {
        if (deniedList[i].value == code) {
          alert("<fmt:message key="textGatewayEdit.codeExists"/>: '"+ code +"'");
          return;
        }
      }

      deniedList[deniedList.length] = {key: name, value: code};
      deniedList.sort();
      refreshDeniedList();
    }


    function removeDeniedCode(index) {
      deniedList.splice(index, 1);
      refreshDeniedList();
    }

    function refreshDeniedList() {
      dwr.util.removeAllRows("deniedList");
      if (deniedList.length != 0){
        hide("noDeniedCodeMsg");
        dwr.util.addRows("deniedList", deniedList, [
          function(data) { return data.key; },
          function(data) { return "(" + data.value + ")"; },
          function(data, options) {
            return "<img src='images/bullet_delete.png' class='ptr' title='<fmt:message key="textGatewayEdit.removeCode"/>' "+
                   "onclick='removeDeniedCode("+ options.rowIndex + ");'/>";
          }
        ], null);
      }
    }

    function allowedRowDown(rowIndex) {
      var temp;
      if (rowIndex < allowedList.length - 1) {
        temp = allowedList[rowIndex];
        allowedList[rowIndex] = allowedList[rowIndex+1]
        allowedList[rowIndex+1]=temp;
        refreshAllowedList();
      }
    }

    function allowedRowUp(rowIndex) {
      var temp;
      if (rowIndex > 0) {
        temp = allowedList[rowIndex];
        allowedList[rowIndex] = allowedList[rowIndex-1]
        allowedList[rowIndex-1]=temp;
        refreshAllowedList();
      }
    }

  </script>

  <table cellspacing="0" cellpadding="0" border="0">
    <tr>
      <td>
        <c:if test="${!empty textGatewayEvents}">
          <table class="borderDiv marB">
            <tr><td class="smallTitle"><fmt:message key="textGatewayEdit.currentAlarms"/></td></tr>
            <c:forEach items="${textGatewayEvents}" var="event">
              <tr><td class="formError">
                <tag:eventIcon eventBean="${event}"/>
                ${event.prettyActiveTimestamp}:
                ${event.message}
              </td></tr>
            </c:forEach>
          </table>
        </c:if>

        <div id="message" class="formError" style="display:none;"></div>

        <div class="borderDiv marR marB">
          <table>
            <tr>
              <td colspan="2" class="smallTitle">
                <tag:img png="phone" title="common.edit"/>
                <fmt:message key="textGatewayEdit.generalProperties"/> <tag:help id="generalTextGatewayProperties"/>
              </td>
            </tr>

            <tr>
              <td class="formLabelRequired"><fmt:message key="textGatewayEdit.name"/></td>
              <td class="formField">
                <input type="text" id="name" value="${textGateway.name}"/>
                <div id="nameMsg" class="formError" style="display:none;"></div>
              </td>
            </tr>

            <tr>
              <td class="formLabelRequired"><fmt:message key="common.xid"/></td>
              <td class="formField">
                <input type="text" id="xid" value="${textGateway.xid}"/>
                <div id="xidMsg" class="formError" style="display:none;"></div>
              </td>
            </tr>

            <tr>
              <td class="formLabelRequired"><fmt:message key="textGatewayEdit.allowedList"/></td>
              <td class="formField">
                <fmt:message key="textGatewayEdit.name"/> <input type="text" id="allowedName" class="formShort"/>
                <fmt:message key="textGatewayEdit.code"/> <input type="text" id="allowedCode" class="formShort"/>
                <tag:img png="add" title="textGatewayEdit.addAllowedCode" onclick="addAllowedCode()"/>
                <table>
                  <tr id="noAllowedCodeMsg" style="display:none"><td><fmt:message key="textGatewayEdit.noAllowedCodes"/></td></tr>

                  <tbody id="allowedList"></tbody>
                </table>
              </td>
            </tr>

            <tr>
              <td class="formLabelRequired"><fmt:message key="textGatewayEdit.deniedList"/></td>
              <td class="formField">
                <fmt:message key="textGatewayEdit.name"/> <input type="text" id="deniedName" class="formShort"/>
                <fmt:message key="textGatewayEdit.code"/> <input type="text" id="deniedCode" class="formShort"/>
                <tag:img png="add" title="textGatewayEdit.addDeniedCode" onclick="addDeniedCode()"/>
                <table>
                  <tr id="noDeniedCodeMsg" style="display:none"><td><fmt:message key="textGatewayEdit.noDeniedCodes"/></td></tr>
                  <tbody id="deniedList"></tbody>
                </table>
              </td>
            </tr>

          </table>
        </div>

        <div>
          <c:choose>
            <c:when test="${textGateway.type.id == applicationScope['constants.TextGatewayVO.Types.SERIAL_MODEM']}">
              <%@ include file="/WEB-INF/jsp/textGatewayEdit/editSerialModem.jsp" %>
            </c:when>
            <c:when test="${textGateway.type.id == applicationScope['constants.TextGatewayVO.Types.IP_MODEM']}">
              <%@ include file="/WEB-INF/jsp/textGatewayEdit/editIpModem.jsp" %>
            </c:when>
          </c:choose>
        </div>
      </td>
    </tr>

    <tr><td>&nbsp;</td></tr>

    <tr>
      <td align="center">
        <input type="button" value="<fmt:message key="common.save"/>" onclick="saveTextGateway()"/>
        <input type="button" value="<fmt:message key="common.cancel"/>" onclick="window.location='text_gateways.shtm'"/>
      </td>
    </tr>
  </table>
</jsp:body>
</tag:page>