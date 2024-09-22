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
<%@page import="ve.org.vemetris.vo.phonesList.SmsRecipient"%>
<c:set var="NEW_ID"><%= Common.NEW_ID %></c:set>

<tag:page dwr="PhonesListsDwr" onload="init">
<jsp:attribute name="subtitle">
  <fmt:message key="header.phonesLists"/>
</jsp:attribute>
<jsp:body>
  <script>
    var users = new Array();
    var editingPhonesList;
    var nextPhoneEntryId = 1;

    function init() {
        PhonesListsDwr.init(function(response) {
            users = response.data.users;
            for (var i=0; i<response.data.lists.length; i++) {
                appendPhonesList(response.data.lists[i].id);
                updatePhonesList(response.data.lists[i]);
            }
            scheduleInit();
        });
    }

    function showPhonesList(plId) {


        if (editingPhonesList)
            stopImageFader("pl"+ editingPhonesList.id +"Img");


        PhonesListsDwr.getPhonesList(plId, function(pl) {


            if (!editingPhonesList)
                show("phonesListDetails");
            editingPhonesList = pl;

            $set("xid", pl.xid);
            $set("name", pl.name);

            dwr.util.removeAllRows("phonesListEntriesTable");
            var entry;
            for (var i=0; i<pl.entries.length; i++) {
                entry = pl.entries[i];
                if (entry.recipientType == <c:out value="<%= SmsRecipient.TYPE_USER %>"/>)
                    appendUserEntry(entry);
                else if (entry.recipientType == <c:out value="<%= SmsRecipient.TYPE_PHONE %>"/>) {
                    entry.referenceId = nextPhoneEntryId++;
                    appendPhoneEntry(entry);
                }
            }

            updateEmptyListMessage();
            updateUserList();

            setInactiveIntervals(pl.inactiveIntervals);

            setUserMessage();
        });


        startImageFader("pl"+ plId +"Img");

        if (plId == ${NEW_ID})
            hide("deletePhonesListImg");
        else
            show("deletePhonesListImg");
    }

    function updateUserList() {
        dwr.util.removeAllOptions(byId("userList"));
        var availUsers = new Array();
        var i, j, user, found;
        for (i=0; i<users.length; i++) {
            user = users[i];
            found = false;
            for (j=0; j<editingPhonesList.entries.length; j++) {
                if (editingPhonesList.entries[j].referenceId && user.id == editingPhonesList.entries[j].referenceId) {
                    found = true;
                    break;
                }
            }

            if (!found)
                availUsers[availUsers.length] = user;
        }
        dwr.util.addOptions(byId("userList"), availUsers, "id", "username");
    }

    function savePhonesList() {
        setUserMessage();
        hideContextualMessages("phonesListDetails")
        hideGenericMessages("genericMessages");

        PhonesListsDwr.savePhonesList(editingPhonesList.id, $get("xid"), $get("name"), createRecipList(),
                getInactiveIntervals(), function(response) {
            if (response.hasMessages)
                showDwrMessages(response.messages, byId("genericMessages"));
            else {
                if (editingPhonesList.id == ${NEW_ID}) {
                    stopImageFader("pl"+ editingPhonesList.id +"Img");
                    editingPhonesList.id = response.data.plId;
                    appendPhonesList(editingPhonesList.id);
                    startImageFader("pl"+ editingPhonesList.id +"Img");
                    setUserMessage("<fmt:message key="phonesLists.added"/>");
                    show("deletePhonesListImg");
                }
                else
                    setUserMessage("<fmt:message key="phonesLists.saved"/>");
                PhonesListsDwr.getPhonesList(editingPhonesList.id, updatePhonesList)
            }
        });
    }

    function sendTestSms() {
        PhonesListsDwr.sendTestSms(editingPhonesList.id, $get("name"), createRecipList(), function(response) {
            stopImageFader("sendTestSmsImg");
            if (response.hasMessages)
                setUserMessage(response.messages[0].genericMessage);
            else
                setUserMessage("<fmt:message key="phonesLists.testSmsMessage"/>");
        });
        startImageFader("sendTestSmsImg");
    }

    function createRecipList() {
        var recipList = new Array();
        for (var i=0; i<editingPhonesList.entries.length; i++) {
            recipList[i] = {
                recipientType : editingPhonesList.entries[i].recipientType,
                referenceId : editingPhonesList.entries[i].referenceId,
                referencePhone : editingPhonesList.entries[i].referencePhone
            };
        }
        return recipList;
    }

    function setUserMessage(message) {
        if (message) {
            show("userMessage");
            $set("userMessage", message);
        }
        else
            hide("userMessage");
    }

    function appendPhonesList(phonesListId) {
        createFromTemplate("pl_TEMPLATE_", phonesListId, "phonesListsTable");
    }

    function updatePhonesList(pl) {
        $set("pl"+ pl.id +"Name", pl.name);
    }

    function createUserEntry() {
        var userId = $get("userList");
        var user = null;
        for (var i=0; i<users.length; i++) {
            if (userId == users[i].id) {
                user = users[i];
                break;
            }
        }

        if (user == null)
            alert("<fmt:message key="phonesLists.noUser"/>");
        else {
            var userEntry = {
                recipientType : <c:out value="<%= SmsRecipient.TYPE_USER %>"/>,
                referenceId : user.id,
                user : user
            };
            editingPhonesList.entries[editingPhonesList.entries.length] = userEntry;
            appendUserEntry(userEntry);
        }
        updateUserList();
        updateEmptyListMessage();
    }

    function appendUserEntry(userEntry) {
        var content = createFromTemplate("pleUser_TEMPLATE_", userEntry.referenceId, "phonesListEntriesTable");
        setUserImg(userEntry.user.admin, userEntry.user.disabled, byId("ple"+ userEntry.referenceId +"Img"));
        byId("ple"+ userEntry.referenceId +"Username").innerHTML = userEntry.user.username;
    }

    function deleteUserEntry(entryId) {
        // Delete the visual entry.
        byId("phonesListEntriesTable").removeChild(byId("pleUser"+ entryId));

        // Delete the list entry.
        for (var i=0; i<editingPhonesList.entries.length; i++) {
            if (editingPhonesList.entries[i].referenceId == entryId) {
                editingPhonesList.entries.splice(i, 1);
                break;
            }
        }

        updateUserList();
        updateEmptyListMessage();
    }

    function createPhoneEntry() {
        var pho = $get("phone");
        if (pho == "") {
            alert("<fmt:message key="phonesLists.noPhone"/>");
            return;
        }
        var phoneEntry = {
            recipientType : <c:out value="<%= SmsRecipient.TYPE_PHONE %>"/>,
            referenceId : nextPhoneEntryId++,
            referencePhone : pho
        };
        editingPhonesList.entries[editingPhonesList.entries.length] = phoneEntry;
        appendPhoneEntry(phoneEntry);
        updateEmptyListMessage();
    }

    function appendPhoneEntry(phoneEntry) {
        var content = createFromTemplate("plePhone_TEMPLATE_", phoneEntry.referenceId, "phonesListEntriesTable");
        byId("ple"+ phoneEntry.referenceId +"Phone").innerHTML = phoneEntry.referencePhone;
    }

    function deletePhoneEntry(entryId) {
        // Delete the visual entry.
        byId("phonesListEntriesTable").removeChild(byId("plePhone"+ entryId));

        // Delete the list entry.
        for (var i=0; i<editingPhonesList.entries.length; i++) {
            if (editingPhonesList.entries[i].referenceId == entryId) {
                editingPhonesList.entries.splice(i, 1);
                break;
            }
        }

        updateEmptyListMessage();
    }

    function updateEmptyListMessage() {
        display("emptyEntryListMessage", editingPhonesList.entries.length == 0);
    }

    function deletePhonesList() {
        PhonesListsDwr.deletePhonesList(editingPhonesList.id, function() {
            stopImageFader(byId("pl"+ editingPhonesList.id +"Img"));
            byId("phonesListsTable").removeChild(byId("pl"+ editingPhonesList.id));
            hide(byId("phonesListDetails"));
            editingPhonesList = null;
        });
    }

    //
    // Schedule editing.
    var mouseDown = false;
    var setOn = false;

    function scheduleInit() {
        var tbody = byId("scheduleRows");
        var i, tr, td, hour, j, tbl2, tr2, td2, k, content, title, intId;
        for (i=0; i<24; i++) {
            tr = appendNewElement("tr", tbody);
            td = appendNewElement("td", tr);
            hour = ""+ i;
            hour = ("00"+ hour).substring(hour.length);
            td.innerHTML = hour +":00 - "+ hour +":59";

            for (j=0; j<7; j++) {
                td = appendNewElement("td", tr);
                td.className = "ptr hreg";
                td.style.paddingLeft = "3px";
                td.onmouseover = function() { hourOver(this); };
                td.onmouseout = function() { hourOut(this); };
                td.onmousedown = function() { return hourDown(this) };

                content = '<table cellspacing="1" cellpadding="0"><tr>';
                for (k=0; k<4; k++) {
                    if (k == 0) title = hour +":00";
                    else if (k == 1) title = hour +":15";
                    else if (k == 2) title = hour +":30";
                    else title = hour +":45";
                    intId = getIntervalId(j, i, k);
                    content += '<td id="ivl'+ intId +'" style="padding-right:2px;" title="'+ title +'"';
                    content += ' class="qreg qon" onmouseover="quarterOver(this)" onmouseout="quarterOut(this)"';
                    content += ' onmousedown="quarterDown(this); return false;">&nbsp;</td>';
                }
                content += '</tr></table>';
                td.innerHTML = content;
            }
        }

        //document.onmousedown = function() { return false; };
        document.onmouseup = function() { mouseDown = false; return false; };
        document.onselectstart = function() { return false; };
    }

    function getIntervalId(day, hour, quarter) {
        var interval = quarter;
        interval += hour * 4;
        interval += day * 96;
        return interval;
    }

    function quarterOver(node) {
        dojo.replaceClass(node, "qhlt", "qreg");
        if (mouseDown)
            setCell(node);
    }

    function quarterOut(node) {
        dojo.replaceClass(node, "qreg", "qhlt");
    }

    function quarterDown(node) {
        mouseDown = true;
        setOn = !isOn(node);
        setCell(node);
        return false;
    }

    function setCell(node, on) {
        if (!on && on != false) on = setOn;
        if (on)
            dojo.replaceClass(node, "qon", "qoff");
        else
            dojo.replaceClass(node, "qoff", "qon");
    }

    function isOn(node) {
        return dojo.hasClass(node, "qon");
    }

    function hourOver(node) {
        dojo.replaceClass(node, "hhlt", "hreg");
        if (mouseDown)
            setHourCells(node);
    }

    function hourOut(node) {
        dojo.replaceClass(node, "hreg", "hhlt");
        if (mouseDown)
            setHourCells(node);
    }

    function hourDown(node) {
        if (mouseDown)
            return;

        var tds = node.getElementsByTagName("td");
        mouseDown = true;
        var allOn = true;
        for (var i=0; i<tds.length; i++) {
            if (!isOn(tds[i])) {
                allOn = false;
                break;
            }
        }
        setOn = !allOn;
        return false;
    }

    function setHourCells(node) {
        var tds = node.getElementsByTagName("td");
        for (var i=0; i<tds.length; i++)
            setCell(tds[i]);
    }

    function setInactiveIntervals(inactive) {
        var d, h, m, iindex = 0, aindex = 0, node;
        for (d=0; d<7; d++) {
            for (h=0; h<24; h++) {
                for (m=0; m<4; m++) {
                    node = byId("ivl"+ iindex);
                    if (inactive.length >= aindex && inactive[aindex] == iindex) {
                        setCell(node, false);
                        aindex++;
                    }
                    else
                        setCell(node, true);
                    iindex++;
                }
            }
        }
    }

    function getInactiveIntervals() {
        var arr = new Array();
        var d, h, m, iindex = 0, node;
        for (d=0; d<7; d++) {
            for (h=0; h<24; h++) {
                for (m=0; m<4; m++) {
                    node = byId("ivl"+ iindex);
                    if (!isOn(node))
                        arr[arr.length] = iindex;
                    iindex++;
                }
            }
        }
        return arr;
    }
  </script>

  <table>
    <tr>
      <td valign="top">
        <div class="borderDiv">
          <table width="100%">
            <tr>
              <td>
                <span class="smallTitle"><fmt:message key="phonesLists.phonesLists"/></span>
                <tag:help id="phonesLists"/>
              </td>
              <td align="right"><tag:img png="book_add_green" title="common.add" onclick="showPhonesList(${NEW_ID})"
                      id="pl${NEW_ID}Img"/></td>
            </tr>
          </table>
          <table id="phonesListsTable">
            <tbody id="pl_TEMPLATE_" onclick="showPhonesList(getMangoId(this))" class="ptr" style="display:none;"><tr>
              <td><tag:img id="pl_TEMPLATE_Img" png="book_green" title="phonesLists.phonesList"/></td>
              <td class="link" id="pl_TEMPLATE_Name"></td>
            </tr></tbody>
          </table>
        </div>
      </td>

      <td valign="top" style="display:none;" id="phonesListDetails">
        <div class="borderDiv">
          <table width="100%">
            <tr>
              <td><span class="smallTitle"><fmt:message key="phonesLists.details"/></span></td>
              <td align="right">
                <tag:img png="save" onclick="savePhonesList();" title="common.save"/>
                <tag:img id="deletePhonesListImg" png="delete" onclick="deletePhonesList();" title="common.delete"/>
                <tag:img id="sendTestSmsImg" png="sms_go" onclick="sendTestSms();" title="common.sendTestSms"/>
              </td>
            </tr>
          </table>

          <table><tr><td colspan="2" id="userMessage" class="formError" style="display:none;"></td></tr></table>

          <table width="100%">
            <tr style="display:none;">
              <td class="formLabelRequired"><fmt:message key="common.xid"/></td>
              <td class="formField"><input type="text" id="xid"/></td>
            </tr>

            <tr>
              <td class="formLabelRequired"><fmt:message key="phonesLists.name"/></td>
              <td class="formField"><input id="name" type="text" onmousedown="this.focus()"/></td>
            </tr>
            <tr><td class="horzSeparator" colspan="2"></td></tr>
            <tr>
              <td class="formLabel"><fmt:message key="phonesLists.addUser"/></td>
              <td class="formField">
                <select id="userList"></select>
                <tag:img png="add" title="common.add" onclick="createUserEntry()"/>
              </td>
            </tr>
            <tr>
              <td class="formLabel"><fmt:message key="phonesLists.addPhone"/></td>
              <td class="formField">
                <input id="phone" type="text" class="formLong" onmousedown="this.focus()"/>
                <tag:img png="add" title="common.add" onclick="createPhoneEntry()"/>
              </td>
            </tr>
          </table>

          <table width="100%">
            <tr><td colspan="3" class="smallTitle"><fmt:message key="phonesLists.entries"/></td></tr>
            <tr id="emptyEntryListMessage">
              <td colspan="3"><fmt:message key="phonesLists.noEntries"/></td>
            </tr>
            <tr id="pleUser_TEMPLATE_" style="display:none;">
              <td width="16"><img id="ple_TEMPLATE_Img" src="images/hourglass.png"/></td>
              <td id="ple_TEMPLATE_Username"></td>
              <td width="16"><tag:img png="bullet_delete" title="common.delete" onclick="deleteUserEntry(getMangoId(this));"/></td>
            </tr>
            <tr id="plePhone_TEMPLATE_" style="display:none;">
              <td width="16"><tag:img png="phone" title="phonesLists.phone"/></td>
              <td id="ple_TEMPLATE_Phone"></td>
              <td width="16"><tag:img png="bullet_delete" title="common.delete" onclick="deletePhoneEntry(getMangoId(this));"/></td>
            </tr>
            <tbody id="phonesListEntriesTable">
              <tr><td width="16"></td><td></td><td width="16"></td></tr>
            </tbody>
          </table>
          <table width="100%">
            <tbody id="genericMessages"></tbody>
          </table>

          <table>
            <tr><td colspan="5" class="horzSeparator" colspan="2"></td></tr>
            <tr>
              <td class="smallTitle"><fmt:message key="common.activeTime"/></td>
              <td class="qreg qon"></td>
              <td><fmt:message key="common.active"/></td>
              <td class="qreg qoff"></td>
              <td><fmt:message key="common.inactive"/></td>
            </tr>
            <tr>
              <td style="padding:5px;" colspan="5" >
                <table cellspacing="0" cellpadding="0">
                  <tr>
                    <td></td>
                    <th><fmt:message key="common.day.short.mon"/></th>
                    <th><fmt:message key="common.day.short.tue"/></th>
                    <th><fmt:message key="common.day.short.wed"/></th>
                    <th><fmt:message key="common.day.short.thu"/></th>
                    <th><fmt:message key="common.day.short.fri"/></th>
                    <th><fmt:message key="common.day.short.sat"/></th>
                    <th><fmt:message key="common.day.short.sun"/></th>
                  </tr>
                  <tbody id="scheduleRows"></tbody>
                </table>
              </td>
            </tr>
          </table>
        </div>
      </td>
    </tr>
  </table>
</jsp:body>
</tag:page>