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
<script type="text/javascript">
    function applyNow() {
        var list=document.getElementById('pointList').childNodes;
        var applyList = [];
        var j=0;

        for(var i=0; i<list.length; i++)
            if(list[i].checked)
                applyList[j++] =list[i].id;

        setDisabled("applyNowBtn", true);
        show("applyNowWarn");
        startImageFader("applyNowImg");

        DataPointEditDwr.CopyPropsToPoints(${dpid}, applyList, $get("copyProps"), $get("copyLogging"), $get("copyText"),
                $get("copyChart"), $get("copyDetectors"), applyNowCB);
    }

    function applyNowCB(result) {
        setDisabled("applyNowBtn", false);
        stopImageFader("applyNowImg");
        hide("applyNowWarn");
        alert(result);
    }

    dojo.addOnLoad(function() {
        if(${!empty dataPoints})
            setDisabled("applyNowBtn", true);
    });

    function copyChanged(){
    var checked=false;
        if(byId("copyProps").checked)
            checked=true;
        if(byId("copyLogging").checked)
            checked=true;
        if(byId("copyText").checked)
            checked=true;
        if(byId("copyChart").checked)
            checked=true;
        if(byId("copyDetectors").checked)
            checked=true;

        if(checked){
            checked=false;

            var list=document.getElementById('pointList').childNodes;
            for(var i=0; i<list.length; i++)
                if(list[i].checked)
                    checked=true;
        }

        setDisabled("applyNowBtn", !checked);
    }

</script>

<c:choose>
  <c:when test="${!empty dataPoints}">
    <div class="borderDiv marB marR">
      <table>
        <tr>
          <td colspan="2">
            <span class="smallTitle"><fmt:message key="pointEdit.points.props"/></span>
            <tag:help id="applyToPoints"/>
          </td>
        </tr>
        <tr>
          <td class="formLabelRequired"><fmt:message key="pointEdit.props.props"/></td>
          <td><input class="formField" type="checkbox" id="copyProps" onclick="copyChanged();"/></td>
        </tr>
        <tr>
          <td class="formLabelRequired"><fmt:message key="pointEdit.logging.props"/></td>
          <td><input class="formField" type="checkbox" id="copyLogging" onclick="copyChanged();"/></td>
        </tr>
        <tr>
          <td class="formLabelRequired"><fmt:message key="pointEdit.text.props"/></td>
          <td><input class="formField" type="checkbox" id="copyText" onclick="copyChanged();"/></td>
        </tr>
        <tr>
          <td class="formLabelRequired"><fmt:message key="pointEdit.chart.props"/></td>
          <td><input class="formField" type="checkbox" id="copyChart" onclick="copyChanged();"/></td>
        </tr>
        <tr>
          <td class="formLabelRequired"><fmt:message key="pointEdit.detectors.eventDetectors"/></td>
          <td><input class="formField" type="checkbox" id="copyDetectors" onclick="copyChanged();"/></td>
        </tr>
        <tr>
          <tr><td colspan="2"></br></td></tr>
        </tr>
        <tr>
          <td class="formLabelRequired"><fmt:message key="pointEdit.points.points"/></td>
          <td class="borderDiv">
            <div id="pointList" style="height: 150px; overflow-y: scroll; min-width: 200px;">
              <c:forEach items="${dataPoints}" var="point">
                <input type="checkbox" id="${point.key}" onclick="copyChanged();"/>${point.value}<br/>
              </c:forEach>
            </div>
          </td>
        </tr>
        <tr>
          <td></td>
          <td align="center"><input id="applyNowBtn" type="button" value="<fmt:message key="pointEdit.points.applyNow"/>" onclick="applyNow();"/></td>
        </tr>
        <tbody id="applyNowWarn" style="display:none">
          <tr>
            <td colspan="2" align="center" class="formError">
            <img id="applyNowImg" src="images/warn.png"/>
            <fmt:message key="pointEdit.points.warn"/>
            </td>
          </tr>
        </tbody>
      </table>
      <span colspan="2"><fmt:message key="pointEdit.points.note"/></span>
    </div>
  </c:when>
</c:choose>