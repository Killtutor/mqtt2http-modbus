/*
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
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
//
// JavaScript functions for managing email & SMS recipient lists composed of mailing lists/ phones lists, individual users, and specific
// email addresses/phones.
// 
// Use:
//   - updateRecipientList(/*Array*/recipientList) to update the current recipient list
//   - createRecipientArray() to return an array of recipients in the given list
//
mango.erecip = {};

mango.erecip.EmailRecipients = function(prefix, testEmailMessage, mailingLists, users) {
    this.prefix = prefix;
    this.testEmailMessage = testEmailMessage;
    this.nextAddressId = 1;
    this.mailingLists = mailingLists;
    this.users = users;
    
    this.write = function(node, varName, id, label) {
        node = getNodeIfString(node);
        var tr = appendNewElement("tr", node);
        if (id)
            tr.id = id;
        
        var td = appendNewElement("td", tr);
        td.className = "formLabelRequired";
        var cnt = label +'<br/>';
        cnt += '<img id="'+ this.prefix +'SendTestImg" src="images/email_go.png" class="ptr"';
        cnt += '        onclick="'+ varName +'.sendTestEmail()" title="'+ mango.i18n["common.sendTestEmail"] +'"/>';
        td.innerHTML = cnt;
        
        td = appendNewElement("td", tr);
        td.className = "formField";
        cnt  = '<table>';
        cnt += '  <tr>';
        cnt += '    <td class="formLabel">'+ mango.i18n["js.email.addMailingList"] +'</td>';
        cnt += '    <td>';
        cnt += '      <select id="'+ this.prefix +'MailingLists"></select>';
        cnt += '      <img src="images/add.png" class="ptr" onclick="'+ varName +'.addMailingList()"/>';
        cnt += '    </td>';
        cnt += '  </tr>';
        cnt += '  <tr>';
        cnt += '    <td class="formLabel">'+ mango.i18n["js.email.addUser"] +'</td>';
        cnt += '    <td>';
        cnt += '      <select id="'+ this.prefix +'Users"></select>';
        cnt += '      <img src="images/add.png" class="ptr" onclick="'+ varName +'.addUser()"/>';
        cnt += '    </td>';
        cnt += '  </tr>';
        cnt += '  <tr>';
        cnt += '    <td class="formLabel">'+ mango.i18n["js.email.addAddress"] +'</td>';
        cnt += '    <td>';
        cnt += '      <input id="'+ this.prefix +'Address" type="text"/>';
        cnt += '      <img src="images/add.png" class="ptr" onclick="'+ varName +'.addAddress()"/>';
        cnt += '    </td>';
        cnt += '  </tr>';
        cnt += '</table>';
        cnt += '<div class="borderDivPadded">';
        cnt += '  <table width="100%">';
        cnt += '    <tr id="'+ this.prefix +'ListEmpty"><td colspan="3">'+ mango.i18n["js.email.noRecipients"] +'</td></tr>';
        cnt += '    <tr id="'+ this.prefix +'_TEMPLATE_" style="display:none;">';
        cnt += '        <td width="16"><img id="'+ this.prefix +'_TEMPLATE_Img"/></td>';
        cnt += '        <td id="'+ this.prefix +'_TEMPLATE_Description"></td>';
        cnt += '        <td width="16"><img src="images/bullet_delete.png" class="ptr"';
        cnt += '                onclick="'+ varName +'.deleteRecipient(getMangoId(this))"/></td>';
        cnt += '    </tr>';
        cnt += '    <tbody id="'+ this.prefix +'List"></tbody>';
        cnt += '  </table>';
        cnt += '</div>';
        cnt += '<span id="'+ this.prefix +'Error" class="formError"></span>';
        td.innerHTML = cnt;
    }
    
    this.repopulateLists = function() {
        dwr.util.removeAllOptions(this.prefix +"MailingLists");
        dwr.util.addOptions(this.prefix +"MailingLists", this.mailingLists, "id", "name");
        dwr.util.removeAllOptions(this.prefix +"Users");
        dwr.util.addOptions(this.prefix +"Users", this.users, "id", "username");
    }

    this.sendTestEmail = function() {
        this.setErrorMessage();
        var emailList = this.createRecipientArray();
        if (emailList.length == 0)
            this.setErrorMessage(mango.i18n["js.email.noRecipForEmail"]);
        else {
            MiscDwr.sendTestEmail(emailList, this.prefix, this.testEmailMessage, dojo.lang.hitch(this, "sendTestEmailCB"));
            startImageFader(byId(this.prefix +"SendTestImg"));
        }
    }

    this.sendTestEmailCB = function(response) {
        stopImageFader(byId(this.prefix +"SendTestImg"));
        if (response.messages.length > 0)
            this.setErrorMessage(response.messages[0]);
        else
            this.setErrorMessage(mango.i18n["js.email.testSent"]);
    }

    this.deleteRecipient = function(id) {
        // Delete the visual entry.
        byId(this.prefix +"List").removeChild(byId(this.prefix + id));
        this.updateOptions(this.prefix +"MailingLists", this.mailingLists, this.prefix +"List", "M", "name");
        this.updateOptions(this.prefix +"Users", this.users, this.prefix +"List", "U", "username");
        this.checkListEmptyMessage();
    }
    
    this.addMailingList = function(mlid) {
        if (!mlid)
            mlid = $get(this.prefix +"MailingLists");
        if (!mlid)
            return;
        var ml = this.getMailingList(mlid);
        if (ml) {
            this.addListEntry("M"+ mlid, "images/book.png", ml.name);
            this.updateOptions(this.prefix +"MailingLists", this.mailingLists, this.prefix +"List", "M", "name");
            this.checkListEmptyMessage();
        }
    }
    
    this.addUser = function(uid) {
        if (!uid)
            uid = $get(this.prefix +"Users");
        if (!uid)
            return;
        var user = this.getUser(uid);
        if (user) {
            this.addListEntry("U"+ uid, "images/user.png", user.username);
            setUserImg(user.admin, user.disabled, byId(this.prefix +"U"+ uid +"Img"));
            this.updateOptions(this.prefix +"Users", this.users, this.prefix +"List", "U", "username");
            this.checkListEmptyMessage();
        }
    }
    
    this.addAddress = function(addr) {
        if (!addr)
            addr = $get(this.prefix +"Address");
        if (addr == "")
            return;
        this.addListEntry("A"+ this.nextAddressId++, "images/email.png", addr);
        this.checkListEmptyMessage();
    }
    
    this.createRecipientArray = function() {
        var recipientList = byId(this.prefix +"List");
        var list = new Array();
        var id;
        for (j=0; j<recipientList.childNodes.length; j++) {
            if (recipientList.childNodes[j].mangoId) {
                id = recipientList.childNodes[j].mangoId;
                if (id.startsWith("M"))
                    list[list.length] = {
                            recipientType: 1, // EmailRecipient.TYPE_MAILING_LIST
                            referenceId: id.substring(1)};
                else if (id.startsWith("U"))
                    list[list.length] = {
                            recipientType: 2, // EmailRecipient.TYPE_USER
                            referenceId: id.substring(1)};
                else if (id.startsWith("A"))
                    list[list.length] = {
                            recipientType: 3, // EmailRecipient.TYPE_ADDRESS
                            referenceAddress: byId(this.prefix + id +"Description").innerHTML};
                else
                    dojo.debug("Unknown recipient mango id: "+ id);
            }
        }
        return list;
    }
    
    this.updateOptions = function(selectId, itemList, recipientListId, prefix, descriptionField) {
        var select = byId(selectId);
        var recipientList = byId(recipientListId);
    
        dwr.util.removeAllOptions(select);
        var addOptions = new Array();
        var i, j, item, found;
        for (i=0; i<itemList.length; i++) {
            item = itemList[i];
            found = false;
            
            for (j=0; j<recipientList.childNodes.length; j++) {
                if (recipientList.childNodes[j].mangoId && prefix + item.id == recipientList.childNodes[j].mangoId) {
                    found = true;
                    break;
                }
            }
            
            if (!found)
                addOptions[addOptions.length] = item;
        }
        dwr.util.addOptions(select, addOptions, "id", descriptionField);
    }
    
    this.addListEntry = function(id, imgName, description) {
        createFromTemplate(this.prefix +"_TEMPLATE_", id, this.prefix +"List");
        byId(this.prefix + id +"Img").src = imgName;
        byId(this.prefix + id +"Description").innerHTML = description;
    }
    
    this.getMailingList = function(id) {
        return getElement(this.mailingLists, id);
    }
    
    this.getUser = function(id) {
        return getElement(this.users, id);
    }
    
    this.checkListEmptyMessage = function() {
        var recipientList = byId(this.prefix +"List");
        // Check if the empty list message should be displayed or not.
        var found = false;
        for (var i=0; i<recipientList.childNodes.length; i++) {
            if (recipientList.childNodes[i].mangoId) {
                found = true;
                break;
            }
        }
        display(this.prefix +"ListEmpty", !found);
    }
    
    this.updateRecipientList = function(recipientList) {
        this.setErrorMessage();
        this.repopulateLists();
        dwr.util.removeAllRows(this.prefix +"List");
        if (!recipientList || recipientList.length == 0)
            this.checkListEmptyMessage();
        else {
            for (var i=0; i<recipientList.length; i++) {
                var recip = recipientList[i];
                if (recip.recipientType == 1) // EmailRecipient.TYPE_MAILING_LIST
                    this.addMailingList(recip.referenceId);
                else if (recip.recipientType == 2) // EmailRecipient.TYPE_USER
                    this.addUser(recip.referenceId);
                else if (recip.recipientType == 3) // EmailRecipient.TYPE_ADDRESS
                    this.addAddress(recip.referenceAddress);
                else
                    dojo.debug("Unknown recipient type id: "+ recip.recipientType);
            }
        }
    }
    
    this.setErrorMessage = function(msg) {
        showMessage(this.prefix +"Error", msg);
    }
}





mango.erecip.SmsRecipients = function(prefix, testSmsMessage, phonesLists, users) {
    this.prefix = prefix;
    this.testSmsMessage = testSmsMessage;
    this.nextPhoneId = 1;
    this.phonesLists = phonesLists;
    this.users = users;
    
    this.write = function(node, varName, id, label) {
        node = getNodeIfString(node);
        var tr = appendNewElement("tr", node);
        if (id)
            tr.id = id;
        
        var td = appendNewElement("td", tr);
        td.className = "formLabelRequired";
        var cnt = label +'<br/>';
        cnt += '<img id="'+ this.prefix +'SendTestSmsImg" src="images/sms_go.png" class="ptr"';
        cnt += '        onclick="'+ varName +'.sendTestSms()" title="'+ mango.i18n["common.sendTestSms"] +'"/>';
        td.innerHTML = cnt;
        
        td = appendNewElement("td", tr);
        td.className = "formField";
        cnt  = '<table>';
        cnt += '  <tr>';
        cnt += '    <td class="formLabel">'+ mango.i18n["js.sms.addPhonesList"] +'</td>';
        cnt += '    <td>';
        cnt += '      <select id="'+ this.prefix +'PhonesLists"></select>';
        cnt += '      <img src="images/add.png" class="ptr" onclick="'+ varName +'.addPhonesList()"/>';
        cnt += '    </td>';
        cnt += '  </tr>';
        cnt += '  <tr>';
        cnt += '    <td class="formLabel">'+ mango.i18n["js.email.addUser"] +'</td>';
        cnt += '    <td>';
        cnt += '      <select id="'+ this.prefix +'Users"></select>';
        cnt += '      <img src="images/add.png" class="ptr" onclick="'+ varName +'.addUser()"/>';
        cnt += '    </td>';
        cnt += '  </tr>';
        cnt += '  <tr>';
        cnt += '    <td class="formLabel">'+ mango.i18n["js.sms.addPhone"] +'</td>';
        cnt += '    <td>';
        cnt += '      <input id="'+ this.prefix +'Phone" type="text"/>';
        cnt += '      <img src="images/add.png" class="ptr" onclick="'+ varName +'.addPhone()"/>';
        cnt += '    </td>';
        cnt += '  </tr>';
        cnt += '</table>';
        cnt += '<div class="borderDivPadded">';
        cnt += '  <table width="100%">';
        cnt += '    <tr id="'+ this.prefix +'ListEmpty"><td colspan="3">'+ mango.i18n["js.email.noRecipients"] +'</td></tr>';
        cnt += '    <tr id="'+ this.prefix +'_TEMPLATE_" style="display:none;">';
        cnt += '        <td width="16"><img id="'+ this.prefix +'_TEMPLATE_Img"/></td>';
        cnt += '        <td id="'+ this.prefix +'_TEMPLATE_Description"></td>';
        cnt += '        <td width="16"><img src="images/bullet_delete.png" class="ptr"';
        cnt += '                onclick="'+ varName +'.deleteRecipient(getMangoId(this))"/></td>';
        cnt += '    </tr>';
        cnt += '    <tbody id="'+ this.prefix +'List"></tbody>';
        cnt += '  </table>';
        cnt += '</div>';
        cnt += '<span id="'+ this.prefix +'Error" class="formError" style="display:none;"></span>';
        td.innerHTML = cnt;
    }
    
    this.repopulateLists = function() {
        dwr.util.removeAllOptions(this.prefix +"PhonesLists");
        dwr.util.addOptions(this.prefix +"PhonesLists", this.phonesLists, "id", "name");
        dwr.util.removeAllOptions(this.prefix +"Users");
        dwr.util.addOptions(this.prefix +"Users", this.users, "id", "username");
    }

    this.sendTestSms = function() {
        this.setErrorMessage();
        var phonesList = this.createRecipientArray();
        if (phonesList.length == 0)
            this.setErrorMessage(mango.i18n["js.sms.noRecipForSms"]);
        else {
            MiscDwr.sendTestSms(phonesList, this.prefix, this.testSmsMessage,dojo.lang.hitch(this, "sendTestSmsCB"));
            startImageFader(byId(this.prefix +"SendTestSmsImg"));
        }
    }

    this.sendTestSmsCB = function(response) {
        stopImageFader(byId(this.prefix +"SendTestSmsImg"));
        if (response.messages.length > 0)
            this.setErrorMessage(response.messages[0]);
        else
            this.setErrorMessage(mango.i18n["js.sms.testSent"]);
    }

    this.deleteRecipient = function(id) {
        // Delete the visual entry.
        byId(this.prefix +"List").removeChild(byId(this.prefix + id));
        this.updateOptions(this.prefix +"PhonesLists", this.phonesLists, this.prefix +"List", "L", "name");
        this.updateOptions(this.prefix +"Users", this.users, this.prefix +"List", "U", "username");
        this.checkListEmptyMessage();
    }
    
    this.addPhonesList = function(plid) {
        if (!plid)
            plid = $get(this.prefix +"PhonesLists");
        if (!plid)
            return;
        var pl = this.getPhonesList(plid);
        if (pl) {
            this.addListEntry("L"+ plid, "images/book_green.png", pl.name);
            this.updateOptions(this.prefix +"PhonesLists", this.phonesLists, this.prefix +"List", "L", "name");
            this.checkListEmptyMessage();
        }
    }
    
    this.addUser = function(uid) {
        if (!uid)
            uid = $get(this.prefix +"Users");
        if (!uid)
            return;
        var user = this.getUser(uid);
        if (user) {
            this.addListEntry("U"+ uid, "images/user.png", user.username);
            setUserImg(user.admin, user.disabled, byId(this.prefix +"U"+ uid +"Img"));
            this.updateOptions(this.prefix +"Users", this.users, this.prefix +"List", "U", "username");
            this.checkListEmptyMessage();
        }
    }
    
    this.addPhone = function(pho) {
        if (!pho)
            pho = $get(this.prefix +"Phone");
        if (pho == "")
            return;
        this.addListEntry("P"+ this.nextPhoneId++, "images/phone.png", pho);
        this.checkListEmptyMessage();
    }
    
    this.createRecipientArray = function() {
        var recipientList = byId(this.prefix +"List");
        var list = new Array();
        var id;
        for (j=0; j<recipientList.childNodes.length; j++) {
            if (recipientList.childNodes[j].mangoId) {
                id = recipientList.childNodes[j].mangoId;
                if (id.startsWith("L"))
                    list[list.length] = {
                            recipientType: 1, // SmsRecipient.TYPE_PHONES_LIST
                            referenceId: id.substring(1)};
                else if (id.startsWith("U"))
                    list[list.length] = {
                            recipientType: 2, // SmsRecipient.TYPE_USER
                            referenceId: id.substring(1)};
                else if (id.startsWith("P"))
                    list[list.length] = {
                            recipientType: 3, // SmsRecipient.TYPE_PHONE
                            referencePhone: byId(this.prefix + id +"Description").innerHTML};
                else
                    dojo.debug("Unknown recipient mango id: "+ id);
            }
        }
        return list;
    }
    
    this.updateOptions = function(selectId, itemList, recipientListId, prefix, descriptionField) {
        var select = byId(selectId);
        var recipientList = byId(recipientListId);
    
        dwr.util.removeAllOptions(select);
        var addOptions = new Array();
        var i, j, item, found;
        for (i=0; i<itemList.length; i++) {
            item = itemList[i];
            found = false;
            
            for (j=0; j<recipientList.childNodes.length; j++) {
                if (recipientList.childNodes[j].mangoId && prefix + item.id == recipientList.childNodes[j].mangoId) {
                    found = true;
                    break;
                }
            }
            
            if (!found)
                addOptions[addOptions.length] = item;
        }
        dwr.util.addOptions(select, addOptions, "id", descriptionField);
    }
    
    this.addListEntry = function(id, imgName, description) {
        createFromTemplate(this.prefix +"_TEMPLATE_", id, this.prefix +"List");
        byId(this.prefix + id +"Img").src = imgName;
        byId(this.prefix + id +"Description").innerHTML = description;
    }
    
    this.getPhonesList = function(id) {
        return getElement(this.phonesLists, id);
    }
    
    this.getUser = function(id) {
        return getElement(this.users, id);
    }
    
    this.checkListEmptyMessage = function() {
        var recipientList = byId(this.prefix +"List");
        // Check if the empty list message should be displayed or not.
        var found = false;
        for (var i=0; i<recipientList.childNodes.length; i++) {
            if (recipientList.childNodes[i].mangoId) {
                found = true;
                break;
            }
        }
        display(this.prefix +"ListEmpty", !found);
    }
    
    this.updateRecipientList = function(recipientList) {
        this.setErrorMessage();
        this.repopulateLists();
        dwr.util.removeAllRows(this.prefix +"List");
        if (!recipientList || recipientList.length == 0)
            this.checkListEmptyMessage();
        else {
            for (var i=0; i<recipientList.length; i++) {
                var recip = recipientList[i];
                if (recip.recipientType == 1) // EmailRecipient.TYPE_PHONES_LIST
                    this.addPhonesList(recip.referenceId);
                else if (recip.recipientType == 2) // EmailRecipient.TYPE_USER
                    this.addUser(recip.referenceId);
                else if (recip.recipientType == 3) // EmailRecipient.TYPE_PHONE
                    this.addPhone(recip.referencePhone);
                else
                    dojo.debug("Unknown recipient type id: "+ recip.recipientType);
            }
        }
    }
    
    this.setErrorMessage = function(msg) {
        showMessage(this.prefix +"Error", msg);
    }
}

