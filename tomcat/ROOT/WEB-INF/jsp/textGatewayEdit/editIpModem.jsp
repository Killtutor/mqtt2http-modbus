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
      hide("ipAddressMsg");

      TextGatewayEditDwr.saveIpModem(name, xid, allowedList, deniedList, $get("simPin"), $get("ipAddress"), $get("port"),
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
            <td class="formLabelRequired"><fmt:message key="textGatewayEdit.ipModem.ipAddress"/></td>
            <td class="formField">
              <input type="text" id="ipAddress" value="${textGateway.ipAddress}"/>
              <div id="ipAddressMsg" class="formError" style="display:none;"></div>
            </td>
          </tr>

          <tr>
            <td class="formLabelRequired"><fmt:message key="textGatewayEdit.ipModem.port"/></td>
            <td class="formField">
              <input type="text" id="port" value="${textGateway.port}"/>
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