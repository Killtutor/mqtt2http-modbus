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
<%@page import="com.serotonin.mango.vo.user.User"%>
<%@page import="com.serotonin.mango.vo.user.UserDetail"%>

<tag:page dwr="UsersDwr" onload="init">
<jsp:attribute name="subtitle">
  <fmt:message key="header.users"/>
</jsp:attribute>
<jsp:body>
  <script type="text/javascript">
    var userId = ${sessionUser.id};
    var editingUserId;
    var editingUserDetails;
    var dataSources;
    var adminUser;
    var superAdminUser;
    var username;

    function init() {
        UsersDwr.getInitData(function(data) {
            superAdminUser=data.superAdmin;

            userDetailTypes = data.userDetailTypes;
            combo = byId("userDetailTypes");
            for (i=0; i< userDetailTypes.length; i++)
              combo.options[i] = new Option(userDetailTypes[i].message,userDetailTypes[i].key);

            if (data.admin) {
                adminUser = true;

                show("userList");
                show("usernameRow");
                show("administrationRow");
                show("disabledRow");
                //show("dataSources");
                show("deleteImg");
                show("auditRow");

                var i, j;
                for (i=0; i<data.users.length; i++) {
                    appendUser(data.users[i].id);
                    updateUser(data.users[i]);
                }

                var dshtml = "", id, dp;
                dataSources = data.dataSources;
                for (i=0; i<dataSources.length; i++) {
                    id = "ds"+ dataSources[i].id;

                    if(superAdminUser){
                        dshtml += '<input type="checkbox" id="'+ id +'" onclick="dataSourceChange(this)">';
                    }else{
                        dshtml += '<label id="'+ id +'" onclick="dataSourceChange(this)">';
                    }
                    dshtml += '<label for="'+ id +'"> '+ dataSources[i].name +'</label><br/>';
                    dshtml += '<div style="margin-left:25px;" id="dsps'+ dataSources[i].id +'">';
                    if (dataSources[i].points.length > 0) {
                        dshtml +=   '<table cellspacing="0" cellpadding="1">';
                        for (j=0; j<dataSources[i].points.length; j++) {
                            dp = dataSources[i].points[j];
                            dshtml += '<tr>';
                            dshtml +=   '<td class="formLabelRequired">'+ dp.name +'</td>';
                            dshtml +=   '<td>';
                            dshtml +=     '<input type="radio" name="dp'+ dp.id +'" id="dp'+ dp.id +'/0" value="0">';
                            dshtml +=             '<label for="dp'+ dp.id +'/0"><fmt:message key="common.access.none"/></label> ';
                            dshtml +=     '<input type="radio" name="dp'+ dp.id +'" id="dp'+ dp.id +'/1" value="1">';
                            dshtml +=             '<label for="dp'+ dp.id +'/1"><fmt:message key="common.access.read"/></label> ';
                            if (dp.settable) {
                                dshtml +=     '<input type="radio" name="dp'+ dp.id +'" id="dp'+ dp.id +'/2" value="2">';
                                dshtml +=             '<label for="dp'+ dp.id +'/2"><fmt:message key="common.access.set"/></label>';
                            }
                            dshtml +=   '</td>';
                            dshtml += '</tr>';
                        }
                        dshtml +=   '</table>';
                    }
                    dshtml += '</div>';
                }
                hide("hourglass");
                byId("dataSourceList").innerHTML = dshtml;
            }
            else {
                // Not an admin user.
                adminUser = false;
                editingUserId = data.user.id;
                hide("hourglass");
                showUserCB(data.user);
            }
        });
    }

    function showUser(userId) {
        if (editingUserId)
            stopImageFader(byId("u"+ editingUserId +"Img"));
        editingUserId = userId;
        UsersDwr.getUser(userId, showUserCB);
        startImageFader(byId("u"+ editingUserId +"Img"));
    }

    function showUserCB(user) {
        show(byId("userDetails"));
        $set("username", user.username);
        if (userId == user.id){
            $set("oldPassword", "");
            show("oldPasswordRow");
            hide("unlockedUserImg");
            hide("lockedUserImg");
        }else{
            hide("oldPasswordRow");

            if(user.lockStatus==<c:out value="<%= User.LockStatuses.UNLOCKED %>"/>){
                if(user.admin){
                    hide("unlockedUserImg");
                    hide("lockedUserImg");
                }else{
                    show("unlockedUserImg");
                    hide("lockedUserImg");
                }
            }else{
                hide("unlockedUserImg");
                show("lockedUserImg");
            }
        }
        editingUserDetails = user.userDetails;
        updateUserDetailEntries();

        $set("password", "");
        $set("passwordConfirm", "");
        $set("administrator", user.admin);
        $set("superAdministrator", user.superAdmin);
        $set("disabled", user.disabled);
        $set("receiveAlarmEmails", user.receiveAlarmEmails);
        $set("receiveAlarmSms", user.receiveAlarmSms);
        $set("receiveOwnAuditEvents", user.receiveOwnAuditEvents);

        if (adminUser && !user.admin || superAdminUser) {
            // Turn off all data sources and set all data points to 'none'.
            var i, j, dscb, dp;
            for (i=0; i<dataSources.length; i++) {
                dscb = byId("ds"+ dataSources[i].id);
                dscb.checked = false;
                dataSourceChange(dscb);
                for (j=0; j<dataSources[i].points.length; j++)
                    $set("dp"+ dataSources[i].points[j].id, "0");
            }

            // Turn on the data sources to which the user has permission.
            for (i=0; i<user.dataSourcePermissions.length; i++) {
                dscb = byId("ds"+ user.dataSourcePermissions[i]);
                dscb.checked = true;
                dataSourceChange(dscb);
            }

            // Update the data point permissions.
            for (i=0; i<user.dataPointPermissions.length; i++)
                $set("dp"+ user.dataPointPermissions[i].dataPointId, user.dataPointPermissions[i].permission);
        }

        setUserMessage();
        updateUserImg();
    }

    function saveUser() {
        setUserMessage();
        if (adminUser) {
            // Create the list of allowed data sources and data point permissions.
            var i, j;
            var dsPermis = new Array();
            var dpPermis = new Array();
            var dpval;
            for (i=0; i<dataSources.length; i++) {
                if (byId("ds"+ dataSources[i].id).checked)
                    dsPermis[dsPermis.length] = dataSources[i].id;
                else {
                    for (j=0; j<dataSources[i].points.length; j++) {
                        dpval = $get("dp"+ dataSources[i].points[j].id);
                        if (dpval == "1" || dpval == "2")
                            dpPermis[dpPermis.length] = {dataPointId: dataSources[i].points[j].id, permission: dpval};
                    }
                }
            }

            UsersDwr.saveUserAdmin(editingUserId, $get("username"), $get("oldPassword"), $get("password"), $get("passwordConfirm"), editingUserDetails,
                    $get("administrator"), $get("disabled"), $get("receiveAlarmEmails"),$get("receiveAlarmSms"), $get("receiveOwnAuditEvents"),
                    dsPermis, dpPermis, saveUserCB);
        }
        else
            UsersDwr.saveUser(editingUserId, $get("oldPassword"), $get("password"), $get("passwordConfirm"), editingUserDetails,
                    $get("receiveAlarmEmails"), $get("receiveAlarmSms"), $get("receiveOwnAuditEvents"), saveUserCB);


        $set("oldPassword", "");
        $set("password", "");
        $set("passwordConfirm", "");
    }

    function saveUserCB(response) {
        if (response.hasMessages)
            showDwrMessages(response.messages, "genericMessages");
        else if (!adminUser)
            setUserMessage("<fmt:message key="users.dataSaved"/>");
        else {
            if (editingUserId == <c:out value="<%= Common.NEW_ID %>"/>) {
                stopImageFader(byId("u"+ editingUserId +"Img"));
                editingUserId = response.data.userId;
                appendUser(editingUserId);
                startImageFader(byId("u"+ editingUserId +"Img"));
                setUserMessage("<fmt:message key="users.added"/>");
            }
            else
                setUserMessage("<fmt:message key="users.saved"/>");
            UsersDwr.getUser(editingUserId, updateUser)
        }
    }

    function sendTestEmail(id) {
        UsersDwr.sendTestEmail(editingUserDetails[id].content, $get("username"), function(result) {
            stopImageFader(byId("sendTestEmailImg" + id));
            if (result.exception)
                setUserMessage(result.exception);
            else
                setUserMessage(result.message);
        });
        startImageFader(byId("sendTestEmailImg" + id));
    }

    function sendTestSms(id) {
        UsersDwr.sendTestSms(editingUserDetails[id].content, $get("username"), function(result) {
            stopImageFader(byId("sendTestSmsImg" + id));
            if (result.exception)
                setUserMessage(result.exception);
            else
                setUserMessage(result.message);
        });
        startImageFader(byId("sendTestSmsImg" + id));
    }

    function setUserMessage(message) {
        if (message)
            $set("userMessage", message);
        else {
            $set("userMessage");
            hideContextualMessages("userDetails");
            hideGenericMessages("genericMessages");
        }
    }

    function appendUser(userId) {
        createFromTemplate("u_TEMPLATE_", userId, "usersTable");
    }

    function updateUser(user) {
        byId("u"+ user.id +"Username").innerHTML = user.username;

        setUserImg(user.admin, user.disabled, byId("u"+ user.id +"Img"));
    }

    function updateUserImg() {
        var superAdmin = $get("superAdministrator");
        var admin = $get("administrator");
        if (superAdminUser) {
            if (superAdmin){
                hide("dataSources");
                hide("administrationRow");
                hide("disabledRow");
                show("auditRow");
            }else{
                show("dataSources");
                show("administrationRow");
                show("disabledRow");

                var i;
                if(admin){
                    for (i=0; i<dataSources.length; i++) {
                        id = "ds"+ dataSources[i].id;
                        setDisabled(id,false);
                    }
                    show("auditRow");
                }else{
                    for (i=0; i<dataSources.length; i++) {
                        id = "ds"+ dataSources[i].id;
                        setDisabled(id,true);
                    }
                    hide("auditRow");
                }
            }
        }else{
            if(adminUser){
                if (admin){
                    hide("dataSources");
                    hide("disabledRow");
                    show("auditRow");
                }else{
                    show("dataSources");
                    show("disabledRow");
                    hide("auditRow");
                }
            }
            hide("administrationRow");
        }
        setUserImg(admin, $get("disabled"), byId("userImg"));
    }

    function dataSourceChange(dscb) {
        display("dsps"+ dscb.id.substring(2), !dscb.checked);
    }

    function deleteUser() {
        if (confirm("<sst:i18n key="users.deleteConfirm" escapeDQuotes="true"/>")) {
            var userId = editingUserId;
            startImageFader("deleteImg");
            UsersDwr.deleteUser(userId, function(response) {
                stopImageFader("deleteImg");

                if (response.hasMessages)
                    setUserMessage(response.messages[0].genericMessage);
                else {
                    stopImageFader("u"+ userId +"Img");
                    byId("usersTable").removeChild(byId("u"+ userId));
                    hide("userDetails");
                    editingUserId = null;
                }
            });
        }
    }

    function toggleLockUser(img) {
        var userId = editingUserId;
        var admin = $get("administrator");
        startImageFader(img);

        UsersDwr.toggleLockUser(userId, function(response) {
            stopImageFader(img);

            if (response.locked){
                hide("unlockedUserImg");
                show("lockedUserImg");
            }else {
                if(admin){
                    hide("unlockedUserImg");
                    hide("lockedUserImg");
                }else{
                    show("unlockedUserImg");
                    hide("lockedUserImg");
                }
            }
        });
    }

    function updateUserDetailEntries(){
        if(editingUserDetails.length>0)
            hide("emptyEntryListMessage");
        else
            show("emptyEntryListMessage");

        byId("udEmailEntriesTable").innerHTML="";
        byId("udPhoneEntriesTable").innerHTML="";

        for(i=0;i<editingUserDetails.length;i++){
            if(editingUserDetails[i].typeId == <c:out value="<%= UserDetail.TYPE_EMAIL %>"/>)
                createFromTemplate("udEmail_TEMPLATE_", i, "udEmailEntriesTable");
            else if(editingUserDetails[i].typeId == <c:out value="<%= UserDetail.TYPE_PHONE %>"/>)
                createFromTemplate("udPhone_TEMPLATE_", i, "udPhoneEntriesTable");

            $set("udName" + i, editingUserDetails[i].name);
            $set("udContent" + i, editingUserDetails[i].content);
            $set("udActive" + i, editingUserDetails[i].active);
        }
    }

    function createUserDetailEntry(){
        var type = $get("userDetailTypes");
        if(type == <c:out value="<%= UserDetail.TYPE_EMAIL %>"/>){
            editingUserDetails[editingUserDetails.length] = {
                typeId: <c:out value="<%= UserDetail.TYPE_EMAIL %>"/>,
                name: "<fmt:message key="users.email"/>",
                content: "",
                active: false
            };
        }else if(type == <c:out value="<%= UserDetail.TYPE_PHONE %>"/>){
            editingUserDetails[editingUserDetails.length] = {
                typeId: <c:out value="<%= UserDetail.TYPE_PHONE %>"/>,
                name: "<fmt:message key="users.phone"/>",
                content: "",
                active: false
            };
        }
        updateUserDetailEntries();
    }

    function deleteEmailEntry(id){
        editingUserDetails.splice(id,1);
        updateUserDetailEntries();
    }

    function deletePhoneEntry(id){
        editingUserDetails.splice(id,1);
        updateUserDetailEntries();
    }

    function updateName(id){
        editingUserDetails[id].name = $get("udName" + id);
    }

    function updateContent(id){
        editingUserDetails[id].content = $get("udContent" + id);
    }

    function updateActive(id){
        editingUserDetails[id].active = $get("udActive" + id);
    }

  </script>

  <table>
    <tr>
      <div id="hourglass" style="padding:6px;text-align:center;"><tag:img png="hourglass"/></div>
    </tr>
    <tr>
      <td valign="top" style="display:none;" id="userList">
        <div class="borderDiv">
          <table width="100%">
            <tr>
              <td>
                <span class="smallTitle"><fmt:message key="users.title"/></span>
                <tag:help id="userAdministration"/>
              </td>
              <td align="right"><tag:img png="user_add" onclick="showUser(${applicationScope['constants.Common.NEW_ID']})"
                      title="users.add" id="u${applicationScope['constants.Common.NEW_ID']}Img"/></td>
            </tr>
          </table>
          <table id="usersTable">
            <tbody id="u_TEMPLATE_" onclick="showUser(getMangoId(this))" class="ptr" style="display:none;"><tr>
              <td><tag:img id="u_TEMPLATE_Img" png="user_green" title="users.user"/></td>
              <td class="link" id="u_TEMPLATE_Username"></td>
            </tr></tbody>
          </table>
        </div>
      </td>

      <td valign="top" style="display:none;" id="userDetails">
        <div class="borderDiv">
          <table width="100%">
            <tr>
              <td>
                <span class="smallTitle"><tag:img id="userImg" png="user_green" title="users.user"/>
                <fmt:message key="users.details"/></span>
              </td>
              <td align="right">
                <tag:img id="unlockedUserImg" png="lock_open" onclick="toggleLockUser('unlockedUserImg');" title="users.unlockedUser"
                        style="display:none;"/>
                <tag:img id="lockedUserImg" png="lock" onclick="toggleLockUser('lockedUserImg');" title="users.lockedUser"
                        style="display:none;"/>
                <tag:img png="save" onclick="saveUser();" title="common.save"/>
                <tag:img id="deleteImg" png="delete" onclick="deleteUser();" title="common.delete" style="display:none;"/>
              </td>
            </tr>
          </table>

          <table><tbody id="genericMessages"></tbody></table>

          <table>
            <tr>
              <td colspan="2" id="userMessage" class="formError"></td>
            </tr>
            <tr id="usernameRow" style="display:none;">
              <td class="formLabelRequired"><fmt:message key="users.username"/></td>
              <td class="formField"><input id="username" type="text"/></td>
            </tr>
            <tr id="oldPasswordRow" style="display:none;">
              <td class="formLabelRequired"><fmt:message key="users.oldPassword"/></td>
              <td class="formField"><input id="oldPassword" type="password"/></td>
            </tr>
            <tr>
              <td class="formLabelRequired"><fmt:message key="users.newPassword"/></td>
              <td class="formField"><input id="password" type="password"/></td>
            </tr>
            <tr>
              <td class="formLabelRequired"><fmt:message key="users.passwordConfirm"/></td>
              <td class="formField"><input id="passwordConfirm" type="password"/></td>
            </tr>
            <tr>
              <td colspan="2">
                <table width="100%" class="borderDiv">
                  <tr>
                    <td class="formLabel"><fmt:message key="users.add"/></td>
                    <td class="formField"><select id="userDetailTypes"></select>
                    <tag:img png="add" title="common.add" onclick="createUserDetailEntry()"/>
                    </td>
                  </tr>
                  <tr>
                    <td colspan="2">
                      <table>
                        <tr id="emptyEntryListMessage">
                          <td colspan="5"><fmt:message key="mailingLists.noEntries"/></td>
                        </tr>
                        <tr id="udEmail_TEMPLATE_" style="display:none;">
                          <td width="16">
                            <c:choose>
                              <c:when test="${sessionUser.admin}">
                                <tag:img id="sendTestEmailImg_TEMPLATE_" png="email_go" onclick="sendTestEmail(_TEMPLATE_);" title="common.sendTestEmail"/>
                              </c:when>
                              <c:otherwise>
                                <tag:img id="sendTestEmailImg_TEMPLATE_" png="email"/>
                              </c:otherwise>
                            </c:choose>
                          </td>
                          <td><input class="hiddenTextarea" id="udName_TEMPLATE_" type="text" label placeholder onChange="updateName(_TEMPLATE_);" title="<fmt:message key="users.email.name"/>"/></td>
                          <td><input id="udContent_TEMPLATE_" type="text" onChange="updateContent(_TEMPLATE_);"/></td>
                          <td><input id="udActive_TEMPLATE_" type="checkbox" onChange="updateActive(_TEMPLATE_);" title="<fmt:message key="users.activate"/>"/></td>
                          <td width="16"><tag:img png="bullet_delete" title="common.delete" onclick="deleteEmailEntry(_TEMPLATE_);"/></td>
                        </tr>
                        <tr id="udPhone_TEMPLATE_" style="display:none;">
                          <td width="16">
                            <c:choose>
                              <c:when test="${sessionUser.admin}">
                                <tag:img id="sendTestSmsImg_TEMPLATE_" png="sms_go" onclick="sendTestSms(_TEMPLATE_);" title="common.sendTestSms"/>
                              </c:when>
                              <c:otherwise>
                                <tag:img id="sendTestSmsImg_TEMPLATE_" png="phone"/>
                              </c:otherwise>
                            </c:choose>
                          </td>
                          <td><input class="hiddenTextarea" id="udName_TEMPLATE_" type="text" onChange="updateName(_TEMPLATE_);" title="<fmt:message key="users.phone.name"/>"/></td>
                          <td><input id="udContent_TEMPLATE_" type="text" onChange="updateContent(_TEMPLATE_);"/></td>
                          <td><input id="udActive_TEMPLATE_" type="checkbox" onChange="updateActive(_TEMPLATE_);" title="<fmt:message key="users.activate"/>"/></td>
                          <td width="16"><tag:img png="bullet_delete" title="common.delete" onclick="deletePhoneEntry(_TEMPLATE_);"/></td>
                        </tr>
                        <tbody id="udEmailEntriesTable">
                          <tr><td width="16"></td><td></td><td width="16"></td></tr>
                        </tbody>
                        <tbody id="udPhoneEntriesTable">
                          <tr><td width="16"></td><td></td><td width="16"></td></tr>
                        </tbody>
                      </table>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>
            <tr id="superAdministrationRow" style="display:none;">
              <td class="formLabelRequired"><fmt:message key="common.superAdministrator"/></td>
              <td class="formField"><input id="superAdministrator" type="checkbox" onclick="updateUserImg();"/></td>
            </tr>
            <tr id="administrationRow" style="display:none;">
              <td class="formLabelRequired"><fmt:message key="common.administrator"/></td>
              <td class="formField"><input id="administrator" type="checkbox" onclick="updateUserImg();"/></td>
            </tr>
            <tr id="disabledRow" style="display:none;">
              <td class="formLabelRequired"><fmt:message key="common.disabled"/></td>
              <td class="formField"><input id="disabled" type="checkbox" onclick="updateUserImg();"/></td>
            </tr>
            <tr>
              <td class="formLabelRequired"><fmt:message key="users.receiveAlarmEmails"/></td>
              <td class="formField"><select id="receiveAlarmEmails"><tag:alarmLevelOptions/></select></td>
            </tr>
            <tr>
              <td class="formLabelRequired"><fmt:message key="users.receiveAlarmSms"/></td>
              <td class="formField"><select id="receiveAlarmSms"><tag:alarmLevelOptions/></select></td>
            </tr>
            <tr id="auditRow" style="display:none;">
              <td class="formLabelRequired"><fmt:message key="users.receiveOwnAuditEvents"/></td>
              <td class="formField"><input id="receiveOwnAuditEvents" type="checkbox"/></td>
            </tr>
            <tbody id="dataSources" style="display:none;">
              <tr><td class="horzSeparator" colspan="2"></td></tr>
              <tr id="dataSources">
                <td class="formLabelRequired"><fmt:message key="users.dataSources"/></td>
                <td class="formField" id="dataSourceList"></td>
              </tr>
            </tbody>
          </table>
        </div>
      </td>
    </tr>
  </table>
</jsp:body>
</tag:page>