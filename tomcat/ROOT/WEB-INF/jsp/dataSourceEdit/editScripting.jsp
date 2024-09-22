<%--
    Mango - Open Source M2M - http://mango.serotoninsoftware.com
    Copyright (C) 2015 Vemetris Software
    @author Alejandro Gonzalez

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
<%@include file="/WEB-INF/jsp/include/tech.jsp" %>
<%@page import="ve.org.vemetris.vo.dataSource.scripting.ScriptingDataSourceVO"%>
<%@page import="com.serotonin.mango.Common"%>
<style>
#scriptCtxmsg { white-space: pre }
</style>
<script type="text/javascript">
  "use strict";
  var pointsArray = new Array();
  var contextArray = new Array();

  function initImpl() {
      <c:forEach items="${userPoints}" var="dp">
      <c:choose>
      <c:when test="${dp.dataSourceId != dataSource.id}">
        pointsArray[pointsArray.length] = {
            id : ${dp.id},
            name : '${sst:quotEncode(dp.extendedName)}',
            type : '<sst:i18n message="${dp.dataTypeMessage}"/>'
        };
      </c:when>
      </c:choose>
      </c:forEach>

      <c:forEach items="${dataSource.context}" var="point">
      addPointToContextInit("${point.key}", "${point.value}");
      </c:forEach>
      writeContextArray();
      createContextualMessageNode("contextContainer", "context"); // ?

      $('#updateEvent').val($('#updateEvent').attr('value')); // el valor en "value" no aplica automaticamente
      updateEventChanged();
  }

  function saveDataSourceImpl() {
      DataSourceEditDwr.saveScriptingDataSource(
              $get("dataSourceName"),
              $get("dataSourceXid"),
              $get("script"),
              createContextArray(),
              $get("executionDelaySeconds"),
              $get("updateEvent"),
              $get("updateCronPattern"),
              saveDataSourceCB);
  }

  function editPointCBImpl(locator) {
      $set("dataTypeId", locator.dataTypeId);
      $set("settable", locator.settable);
  }

  function savePointImpl(locator) {
      locator.dataTypeId = $get("dataTypeId");
      locator.settable = $get("settable");
      DataSourceEditDwr.saveScriptingPointLocator(currentPoint.id, $get("xid"), $get("name"), $get("deviceName"), locator, savePointCB);
  }

  var addPointToContextInit = function(pointId, scriptVarName) {
      var data = getElement(pointsArray, pointId);
      contextArray.push({
          pointId : pointId,
          pointName : data.name,
          pointType : data.type,
          scriptVarName : scriptVarName
      });
  };

  function addPointToContext() {
      var pointId = $get("allPointsList");
      addToContextArray(pointId, "p"+ pointId);
      writeContextArray();
  }

  function addToContextArray(pointId, scriptVarName) {
      var data = getElement(pointsArray, pointId);
      if (data) {
          // Missing names imply that the point was deleted, so ignore.
          contextArray[contextArray.length] = {
              pointId : pointId,
              pointName : data.name,
              pointType : data.type,
              scriptVarName : scriptVarName
          };
      }
  }

  function removeFromContextArray(pointId) {
      for (var i = contextArray.length - 1; i >= 0; i--) {
          if (contextArray[i].pointId == pointId)
              contextArray.splice(i, 1);
      }
      writeContextArray();
  }

  function writeContextArray() {
      dwr.util.removeAllRows("contextTable");
      if (contextArray.length == 0) {
          show(byId("contextTableEmpty"));
          hide(byId("contextTableHeaders"));
      }
      else {
          hide(byId("contextTableEmpty"));
          show(byId("contextTableHeaders"));
          dwr.util.addRows("contextTable", contextArray,
              [
                  function(data) { return data.pointName; },
                  function(data) { return data.pointType; },
                  function(data) {
                          return "<input type='text' value='"+ data.scriptVarName +"' class='formShort' "+
                                  "onblur='updateScriptVarName("+ data.pointId +", this.value)'/>";
                  },
                  function(data) {
                          return "<img src='images/bullet_delete.png' class='ptr' "+
                                  "onclick='removeFromContextArray("+ data.pointId +")'/>";
                  }
              ],
              {
                  rowCreator:function(options) {
                      var tr = document.createElement("tr");
                      tr.className = "smRow"+ (options.rowIndex % 2 == 0 ? "" : "Alt");
                      return tr;
                  }
              });
      }
      updatePointsList();
  }

  function updatePointsList() {
      dwr.util.removeAllOptions("allPointsList");
      var availPoints = new Array();
      for (var i = 0; i < pointsArray.length; i++) {
          var found = false;
          for (var j = 0; j < contextArray.length; j++) {
              if (contextArray[j].pointId == pointsArray[i].id) {
                  found = true;
                  break;
              }
          }

          if (!found)
              availPoints[availPoints.length] = pointsArray[i];
      }
      dwr.util.addOptions("allPointsList", availPoints, "id", "name");
  }

  function updateScriptVarName(pointId, scriptVarName) {
      for (var i = contextArray.length - 1; i >= 0; i--) {
          if (contextArray[i].pointId == pointId)
              contextArray[i].scriptVarName = scriptVarName;
      }
  }

  function createContextArray() {
      var context = new Array();
      for (var i = 0; i < contextArray.length; i++) {
          context[context.length] = {
              key : contextArray[i].pointId,
              value : contextArray[i].scriptVarName
          };
      }
      return context;
  }

  function validateScript() {
      hideContextualMessages("pointProperties"); // ?
      DataSourceEditDwr.validateScriptingScript($get("script"), createContextArray(), validateScriptCB);
  }

  function validateScriptCB(response) {
      showDwrMessages(response.messages);
  }

  function updateEventChanged() {
      display("updateCronPatternRow", $get("updateEvent") == <%= ScriptingDataSourceVO.UPDATE_EVENT_CRON %>);
  }
</script>

<c:set var="dsDesc"><fmt:message key="dsEdit.scripting.desc"/></c:set>
<c:set var="dsHelpId" value="scriptingDS"/>
<%@ include file="/WEB-INF/jsp/dataSourceEdit/dsHead.jspf" %>

  <tr>
    <td class="formLabelRequired"><fmt:message key="dsEdit.scripting.scriptContext"/></td>
    <td class="formField">
      <select id="allPointsList"></select>
      <tag:img png="add" onclick="addPointToContext();" title="common.add"/>

      <table cellspacing="1" id="contextContainer">
        <tbody id="contextTableEmpty" style="display:none;">
          <tr><th colspan="4"><fmt:message key="dsEdit.scripting.noPoints"/></th></tr>
        </tbody>
        <tbody id="contextTableHeaders" style="display:none;">
          <tr class="smRowHeader">
            <td><fmt:message key="dsEdit.scripting.pointName"/></td>
            <td><fmt:message key="dsEdit.pointDataType"/></td>
            <td><fmt:message key="dsEdit.scripting.var"/></td>
            <td></td>
          </tr>
        </tbody>
        <tbody id="contextTable"></tbody>
      </table>
    </td>
  </tr>

  <tr>
    <td class="formLabelRequired">
      <fmt:message key="dsEdit.scripting.script"/> <tag:img png="accept" onclick="validateScript();" title="dsEdit.scripting.validate"/>
    </td>
    <td class="formField"><textarea id="script" rows="10" cols="50"/>${dataSource.script}</textarea></td>
  </tr>

  <tr>
    <td class="formLabelRequired"><fmt:message key="dsEdit.scripting.event"/></td>
    <td class="formField">
      <select id="updateEvent" onchange="updateEventChanged()" value="${dataSource.updateEvent}">
        <option value="<c:out value="<%= ScriptingDataSourceVO.UPDATE_EVENT_CRON %>"/>"><fmt:message key="dsEdit.scripting.event.cron"/></option>
        <option value="<c:out value="<%= ScriptingDataSourceVO.UPDATE_EVENT_CONTEXT_UPDATE %>"/>"><fmt:message key="dsEdit.scripting.event.context"/></option>
        <option value="<c:out value="<%= Common.TimePeriods.MINUTES %>"/>"><fmt:message key="dsEdit.scripting.event.minute"/></option>
        <option value="<c:out value="<%= Common.TimePeriods.HOURS %>"/>"><fmt:message key="dsEdit.scripting.event.hour"/></option>
        <option value="<c:out value="<%= Common.TimePeriods.DAYS %>"/>"><fmt:message key="dsEdit.scripting.event.day"/></option>
        <option value="<c:out value="<%= Common.TimePeriods.WEEKS %>"/>"><fmt:message key="dsEdit.scripting.event.week"/></option>
        <option value="<c:out value="<%= Common.TimePeriods.MONTHS %>"/>"><fmt:message key="dsEdit.scripting.event.month"/></option>
        <option value="<c:out value="<%= Common.TimePeriods.YEARS %>"/>"><fmt:message key="dsEdit.scripting.event.year"/></option>
      </select>
    </td>
  </tr>

  <tr id="updateCronPatternRow">
    <td class="formLabelRequired"><fmt:message key="dsEdit.scripting.event.cron"/></td>
    <td class="formField"><input id="updateCronPattern" type="text" value="${dataSource.updateCronPattern}"/> <tag:help id="cronPatterns"/></td>
  </tr>

  <tr>
    <td class="formLabelRequired"><fmt:message key="dsEdit.scripting.delay"/></td>
    <td class="formField"><input id="executionDelaySeconds" type="text" class="formShort" value="${dataSource.executionDelaySeconds}"/></td>
  </tr>

<%@ include file="/WEB-INF/jsp/dataSourceEdit/dsEventsFoot.jspf" %>

<tag:pointList pointHelpId="scriptingPP">
  <tr>
    <td class="formLabelRequired"><fmt:message key="dsEdit.pointDataType"/></td>
    <td class="formField">
      <select id="dataTypeId">
        <tag:dataTypeOptions excludeImage="true"/>
      </select>
    </td>
  </tr>

  <tr>
    <td class="formLabelRequired"><fmt:message key="dsEdit.settable"/></td>
    <td class="formField"><input type="checkbox" id="settable"/></td>
  </tr>

</tag:pointList>