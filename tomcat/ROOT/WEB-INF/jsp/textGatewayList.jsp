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
<tag:page dwr="TextGatewayListDwr" onload="init">
<jsp:attribute name="subtitle">
  <fmt:message key="header.textGateways"/>
</jsp:attribute>
<jsp:body>
  <script type="text/javascript">

  var textGateways = new Array();
    function init() {
        TextGatewayListDwr.init(function(response) {
            dwr.util.addOptions("textGatewayTypes", response.data.textGatewayTypes, "key", "message");

            updateTextGatewayList(response.data.textGateways);

            textGateways = response.data.textGateways;
            var combo = byId("textGatewayId");
            for (i=0; i< textGateways.length; i++)
              combo.options[i+1] = new Option(textGateways[i].name,textGateways[i].id);

            textMessageStatus = response.data.textMessageStatus;
            combo = byId("textMessageStatus");
            for (i=0; i< textMessageStatus.length; i++)
              combo.options[i+1] = new Option(textMessageStatus[i].message,textMessageStatus[i].key);
        });
    }

    function addTextGateway() {
        window.location = "text_gateway_edit.shtm?typeId="+ $get("textGatewayTypes");
    }

    function refreshTextMessageList(response) {
        stopImageFader("updateTextMessageListImg");
        dwr.util.removeAllRows("textMessageList");

        var combo = byId("pageList");
        var page = combo.selectedIndex;
        if (page == null)
            page=0;

        for (i=0; i< combo.options.length; i++)
            combo.options.remove(i);

        for (i=0; i< response.data.pages; i++)
            combo.options[i] = new Option(i+1,i);

        if(page < response.data.pages)
            combo.selectedIndex = page;
        else
            combo.selectedIndex = response.data.pages -1;

        if (response.data.pages>1)
            show("pageTable");
        else
            hide("pageTable");

        var dateTimes = response.data.dateTimes;
        var returnDateTimes = response.data.returnDateTimes;
        var status = response.data.messageStatus;
        var index=0;
        if (response.data.textMessages.length == 0)
            show("noMessages");
        else {
            hide("noMessages");
            dwr.util.addRows("textMessageList", response.data.textMessages,
                [
                    function(data) { return data.id; },
                    function(data) { return dateTimes[index]; },
                    function(data) {

                    var name = "";
                    for (i=0; i<textGateways.length; i++){
                        if (textGateways[i].id == data.textGateway){
                            name = textGateways[i].name;
                            break;
                        }
                    }
                    return name; },
                    function(data) { return data.recipient; },
                    function(data) { return data.content; },
                    function(data) { return status[index]; },
                    function(data) { return returnDateTimes[index++];},
                    function(data) { return "<input type='checkbox'"+ (data.preventPurge ? " checked='checked'" : "") +
                                " onclick='TextGatewayListDwr.setPreventPurge("+ data.id +", this.checked)'/>"; }
                ],
                {
                    rowCreator: function(options) {
                        var tr = document.createElement("tr");
                        tr.className = "row"+ (options.rowIndex % 2 == 0 ? "" : "Alt");
                        return tr;
                    },
                    cellCreator: function(options) {
                        var td = document.createElement("td");
                        if (options.cellNum == 1)
                            td.align = "center";
                        if (options.cellNum == 3)
                            td.align = "center";
                        if (options.cellNum == 6)
                            td.align = "center";
                        if (options.cellNum == 7)
                            td.align = "center";
                        if (options.cellNum == 8)
                            td.align = "center";
                        return td;
                    }
                });
        }
    }

    function updateTextMessageList() {
        TextGatewayListDwr.getTextMessages($get("textMessageId"), $get("textGatewayId"),$get("textMessageStatus"),$get("pageList"), refreshTextMessageList);
        startImageFader("updateTextMessageListImg");

        hide("hourglass");
        show("textMessageTable");
    }

    function deleteMessage(Id) {
        var img = byId("msg"+ Id +"DeleteImg");
        img.src = "images/bullet_black.png";
        img.onclick = null;
        dojo.removeClass(img, "ptr");
        startImageFader("updateTextMessageListImg");
        TextGatewayListDwr.deleteMessage(Id, refreshTextMessageList);
    }

    function updateTextGatewayList(textGateways) {
        dwr.util.removeAllRows("textGatewayList");
        dwr.util.addRows("textGatewayList", textGateways,
            [

                function(tg) {
                    return '<img src="images/arrow_up_thin.png" title="<fmt:message key="textGatewayList.moveUp"/>" '+
                            'class="ptr" onclick="moveRowUp('+ tg.id +')" id="textGatewayRow'+ tg.id +'MoveUp"/> '+
                           '<img src="images/arrow_down_thin.png" title="<fmt:message key="textGatewayList.moveDown"/>" '+
                            'class="ptr" onclick="moveRowDown('+ tg.id +')" id="textGatewayRow'+ tg.id +'MoveDown"/> ';
                },
                function(tg) { return "<b>" + tg.name + "</b>"; },
                function(tg) { return tg.typeMessage; },
                function(tg) { return tg.configDescription; },


                function(tg) {
                    if (tg.enabled)
                        return '<img src="images/phone_go.png" title="<fmt:message key="common.enabledToggle"/>" '+
                            'class="ptr" onclick="toggleTextGateway('+ tg.id +')" id="tgImg'+ tg.id +'"/>';
                    return '<img src="images/phone_stop.png" title="<fmt:message key="common.disabledToggle"/>" '+
                        'class="ptr" onclick="toggleTextGateway('+ tg.id +')" id="tgImg'+ tg.id +'"/>';
                },
                function(tg) {
                    var data="";
                    if (tg.allowedList.length > 0){
                        for(i=0; i<tg.allowedList.length; i++){
                            if (i==2 && tg.allowedList.length > 3){
                                data += tg.allowedList[i].value + ", ...";
                                break;
                            }

                            if (i == tg.allowedList.length - 1){
                                data += tg.allowedList[i].value;
                                break;
                            }
                            data += tg.allowedList[i].value + ", ";
                        }
                        return data;
                    }

                    return '<center><fmt:message key="textGatewayList.noPrioritys"/></center>';
                },
                function(tg) {
                    var data="";
                    if (tg.deniedList.length > 0){
                        for(i=0; i<tg.deniedList.length; i++){
                            if (i==2 && tg.deniedList.length > 3){
                                data += tg.deniedList[i].value + ", ...";
                                break;
                            }

                            if (i == tg.deniedList.length - 1){
                                data += tg.deniedList[i].value;
                                break;
                            }
                            data += tg.deniedList[i].value + ", ";
                        }
                        return data;
                    }

                    return '<center><fmt:message key="textGatewayList.noExclusions"/></center>';
                },
                function(tg) {
                    return  '<img src="images/cog_go.png" title="<fmt:message key="textGatewayList.ussd"/>" id="ussdImg'+ tg.id +'" '+
                            'class="ptr" onclick="sendUSSD('+ tg.id +')"/> '+
                            '<img src="images/phone_sound.png" title="<fmt:message key="textGatewayList.signal"/>" id="infoImg'+ tg.id +'" '+
                            'class="ptr" onclick="getTextGatewayInfo('+ tg.id +')"/> '+
                            '<a href="text_gateway_edit.shtm?tgid='+ tg.id +'"><img src="images/phone_edit.png" '+
                            'border="0" title="<fmt:message key="common.edit"/>"/></a> '+
                           '<c:if test="${sessionUser.superAdmin}"><img src="images/phone_delete.png" title="<fmt:message key="common.delete"/>" id="deleteImg'+ tg.id +'" '+
                            'class="ptr" onclick="deleteTextGateway('+ tg.id +')"/></c:if>';
                }
            ],
            {
                rowCreator: function(options) {
                    var tr = document.createElement("tr");
                    tr.id = "textGatewayRow"+ options.rowData.id;
                    tr.className = "row"+ (options.rowIndex % 2 == 0 ? "" : "Alt");
                    return tr;
                },
                cellCreator: function(options) {
                    var td = document.createElement("td");
                    if (options.cellNum == 3)
                        td.align = "center";
                    if (options.cellNum == 4)
                        td.align = "center";
                    return td;
                }
            });
        display("noTextGateways", textGateways.length == 0);
        fixRowFormatting();
    }

    function toggleTextGateway(id) {
        var imgNode = byId("tgImg"+ id);
        if (!hasImageFader(imgNode)) {
            TextGatewayListDwr.toggleTextGateway(id, function(result) {
                updateStatusImg(byId("tgImg"+ result.data.id), result.data.enabled);
            });
            startImageFader(imgNode);
        }
    }


    function deleteTextGateway(id) {
        if (confirm("<fmt:message key="textGatewayList.deleteConfirm"/>")) {
            startImageFader("deleteImg"+ id);
            TextGatewayListDwr.deleteTextGateway(id, function(textGatewayId) {
                stopImageFader("deleteImg"+ textGatewayId);
                var row = byId("textGatewayRow"+ textGatewayId);
                row.parentNode.removeChild(row);
                fixRowFormatting();
            });

        }
    }

    function getTextGatewayInfo(id) {
        startImageFader("infoImg"+ id);
        TextGatewayListDwr.getTextGatewayInfo(id, function(result){
            stopImageFader("infoImg"+ id);
            alert(result);
        });
    }

    function sendUSSD(id){
        sendUSSDCommand(id,"Command");
    }

    function sendUSSDCommand(id, command) {
        startImageFader("ussdImg"+ id);
        var command = prompt(command);

        if(command != "" && command != null){
            TextGatewayListDwr.sendUSSDCommand(id, command, function(result){
                stopImageFader("ussdImg"+ id);
                sendUSSDCommand(id, result);
            });
        }else{
            stopImageFader("ussdImg"+ id);
        }
    }

    function updateStatusImg(imgNode, enabled) {
        stopImageFader(imgNode);
        setTextGatewayStatusImg(enabled, imgNode);
    }



      function moveRowDown(textGatewayId) {

          var textGatewaysTable = byId("textGatewayList");
          var rows = textGatewaysTable.rows;
          var i=0;

          for (; i<rows.length; i++) {
              if (rows[i].id == "textGatewayRow" + textGatewayId)
                  break;
          }

          if (i < rows.length - 1) {
              if (i == rows.length - 1)
                  textGatewaysTable.append(rows[i]);
              else
                  textGatewaysTable.insertBefore(rows[i], rows[i+2]);
              TextGatewayListDwr.moveDown(textGatewayId);
              fixRowFormatting();
          }
      }

      function moveRowUp(textGatewayId) {
          var textGatewaysTable = byId("textGatewayList");
          var rows = textGatewaysTable.rows;
          var i=0;

          for (; i<rows.length; i++) {
              if (rows[i].id == "textGatewayRow" + textGatewayId)
                  break;
          }

          if (i != 0) {
              textGatewaysTable.insertBefore(rows[i], rows[i-1]);
              TextGatewayListDwr.moveUp(textGatewayId);
              fixRowFormatting();
          }
      }

      function fixRowFormatting() {

          var textGatewaysTable = byId("textGatewayList");
          var rows = textGatewaysTable.rows;

          for (i=0; i<rows.length; i++)
          rows[i].className = "row"+ (i % 2 == 0 ? "" : "Alt");

          if (rows.length == 0) {
              show("noTextGateways");
          }
          else {
              hide("noTextGateways");
              for (var i=0; i<rows.length; i++) {
                  if (i == 0) {
                      hide(rows[i].id +"MoveUp");
                  }
                  else {
                      show(rows[i].id +"MoveUp");
                      show(rows[i].id +"MoveDown");
                  }

                  if (i == rows.length - 1)
                      hide(rows[i].id +"MoveDown");
              }
          }
      }

  </script>

  <table cellspacing="0" cellpadding="0" id="textGatewaysTable">
    <tr>
      <td>
        <tag:img png="phone" title="textGatewayList.textGateways"/>
        <span class="smallTitle"><fmt:message key="textGatewayList.textGateways"/></span>
        <tag:help id="textGatewayList"/>
      </td>
      <c:if test="${sessionUser.superAdmin}">
        <td align="right">
          <select id="textGatewayTypes"></select>
          <tag:img png="phone_add" title="common.add" onclick="addTextGateway()"/>
        </td>
      </c:if>
    </tr>
    <tr>
      <td colspan="2">
        <table cellspacing="1" cellpadding="0" border="0">
          <tr class="rowHeader">
            <td></td>
            <td><fmt:message key="textGatewayList.name"/></td>
            <td><fmt:message key="textGatewayList.type"/></td>
            <td><fmt:message key="textGatewayList.config"/></td>
            <td><fmt:message key="textGatewayList.status"/></td>
            <td><fmt:message key="textGatewayList.prioritys"/></td>
            <td><fmt:message key="textGatewayList.denieds"/></td>
            <td></td>
          </tr>
          <tbody id="noTextGateways" style="display:none"><tr><td colspan="5"><fmt:message key="textGatewayList.noRows"/></td></tr></tbody>
          <tbody id="textGatewayList"></tbody>
        </table>
      </td>
    </tr>
  </table>
  <br><br>
  <table cellpadding="0" cellspacing="0" >
    <tr>
      <td>
        <div class="borderDiv marB" style="max-height:600px;overflow:auto;clear:right;float:left;">
          <table style="width:100%">
            <tr>
              <td>
                <span class="smallTitle"><fmt:message key="text.message.list.textMessageList"/></span>
                <tag:help id="textMessageList"/>
              </td>
              <td align="right">
                <tag:img id="updateTextMessageListImg" png="control_play_blue" title="common.refresh" onclick="updateTextMessageList()"/>
              </td>
            </tr>
          </table>
          <table border="0" align="left">
            <tr>
              <td class="formLabelRequired"><fmt:message key="text.message.id"/></td>
              <td class="formField">
                <input type="text" id="textMessageId" value="" class="formShort"/>
              </td>
              <td class="formLabelRequired"><fmt:message key="text.message.textGateway"/></td>
              <td class="formField">
                <sst:select id="textGatewayId" value="0">
                  <sst:option value="0"><fmt:message key="text.message.list.all"/></sst:option>
                </sst:select>
              </td>
              <td class="formLabelRequired"><fmt:message key="text.message.status"/></td>
              <td class="formField">
                <sst:select id="textMessageStatus" value="-1">
                  <sst:option value="-1"><fmt:message key="text.message.list.all"/></sst:option>
                </sst:select>
              </td>
            </tr>
          </table>
          <br><br>
          <table cellspacing="2" id="textMessageTable" align="left" style="clear:left;display:none;">
            <tr class="rowHeader">
              <td><fmt:message key="text.message.id"/></td>
              <td><fmt:message key="text.message.dateTime"/></td>
              <td><fmt:message key="text.message.textGateway"/></td>
              <td><fmt:message key="text.message.recipient"/></td>
              <td><fmt:message key="text.message.content"/></td>
              <td><fmt:message key="text.message.status"/></td>
              <td><fmt:message key="text.message.returnDateTime"/></td>
              <td><fmt:message key="text.message.list.doNotPurge"/></td>
            </tr>
            <tr id="hourglass" class="row"><td colspan="9" align="center"><tag:img png="hourglass" title="text.message.list.loading"/></td></tr>
            <tr id="noMessages" class="row" style="display:none;"><td colspan="9"><fmt:message key="text.message.list.empty"/></td></tr>
            <tbody id="textMessageList"></tbody>
          </table>
          <table cellspacing="1" align="right" id="pageTable" style="display:none;">
            <td class="formLabelRequired"><fmt:message key="text.message.list.page"/></td>
            <td class="formField">
              <select id="pageList" value="0" onchange="updateTextMessageList()">
                <option value="0">1</option>
              </select>
              <tbody id="textMessagePages"></tbody>
            </td>
          </table>
        </div>
      </td>
    </tr>
  </table>
</jsp:body>
</tag:page>