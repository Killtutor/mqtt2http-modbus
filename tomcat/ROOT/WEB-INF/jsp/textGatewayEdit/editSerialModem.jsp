<%--
    Vemetris - Open Source M2M - http://www.vemetris.com
    Copyright (C) 2006-2011 Serotonin Software Technologies Inc.
    @author Andres Ponte

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


<script type="text/javascript">
  var allPoints = new Array();
  var selectedPoints = new Array();


  function saveTextGatewayImpl(name, xid) {
      // Clear messages.
      hide("simPinMsg");
      hide("portMsg");

      TextGatewayEditDwr.saveSerialModem(name, xid, allowedList, deniedList, $get("simPin"), $get("commPortId"), $get("baud"),
            $get("protocol"), $get("manufacturer"), $get("model"), saveTextGatewayCB);
  }

</script>

<table cellpadding="0" cellspacing="0">
  <tr>
    <td valign="top">
      <div class="borderDiv marR marB">
        <table>
          <tr>
            <td colspan="2" class="smallTitle"><fmt:message key="textGatewayEdit.serialModem.props"/> <tag:help id="serialModemTG"/></td>
          </tr>

          <tr>
            <td class="formLabelRequired"><fmt:message key="textGatewayEdit.serialModem.manufacturer"/></td>
            <td class="formField">
              <input type="text" id="manufacturer" value="${textGateway.manufacturer}"/>
            </td>
          </tr>

          <tr>
            <td class="formLabelRequired"><fmt:message key="textGatewayEdit.serialModem.model"/></td>
            <td class="formField">
              <input type="text" id="model" value="${textGateway.model}"/>
            </td>
          </tr>

          <tr>
            <td class="formLabelRequired"><fmt:message key="textGatewayEdit.serialModem.simPin"/></td>
            <td class="formField">
              <input type="text" id="simPin" value="${textGateway.simPin}"/>
              <div id="simPinMsg" class="formError" style="display:none;"></div>
            </td>
          </tr>

          <tr>
            <td class="formLabelRequired"><fmt:message key="textGatewayEdit.serialModem.port"/></td>
            <td class="formField">
              <c:choose>
                <c:when test="${!empty commPortError}">
                  <input id="commPortId" type="hidden" value=""/>
                  <div id="portMsg" class="formError">${commPortError}</div>
                </c:when>
                <c:otherwise>
                  <sst:select id="commPortId" value="${textGateway.port}">
                    <c:forEach items="${commPorts}" var="port">
                      <sst:option value="${port.name}">${port.name}</sst:option>
                    </c:forEach>
                  </sst:select>
                  <div id="portMsg" class="formError" style="display:none;"></div>
                </c:otherwise>
              </c:choose>
            </td>
          </tr>

          <tr>
            <td class="formLabelRequired"><fmt:message key="textGatewayEdit.serialModem.baud"/></td>
            <td class="formField">
              <sst:select id="baud" value="${textGateway.baud}">
                <sst:option value="110">110</sst:option>
                <sst:option value="300">300</sst:option>
                <sst:option value="600">600</sst:option>
                <sst:option value="1200">1200</sst:option>
                <sst:option value="2400">2400</sst:option>
                <sst:option value="4800">4800</sst:option>
                <sst:option value="9600">9600</sst:option>
                <sst:option value="19200">19200</sst:option>
                <sst:option value="38400">38400</sst:option>
                <sst:option value="57600">57600</sst:option>
                <sst:option value="115200">115200</sst:option>
              </sst:select>
            </td>
          </tr>

          <tr>
            <td class="formLabelRequired"><fmt:message key="textGatewayEdit.serialModem.protocol"/></td>
            <td class="formField">
              <sst:select id="protocol" value="${textGateway.protocol}">
                <sst:option value="1">PDU</sst:option>
                <sst:option value="2">TEXT</sst:option>
              </sst:select>
            </td>
          </tr>

        </table>
      </div>
    </td>
  </tr>
</table>