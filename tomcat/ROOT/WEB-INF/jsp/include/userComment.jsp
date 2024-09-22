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
<%--
  Usage:
    For event comments, your table of events should be id'd "eventsTable". Each events table row should include a
    table with a tbody id'd eventComments<eventId>.

    For data point comments, ...
--%>
<%@ include file="/WEB-INF/jsp/include/tech.jsp" %>
<%@page import="com.serotonin.mango.vo.user.UserComment"%>
<script type="text/javascript">
  require(["dijit/Dialog", "dijit/form/SimpleTextarea", "dijit/form/Button", "dojo/domReady!"], function(Dialog, SimpleTextarea, Button){
      userCommentDialog = new Dialog({
          title: "<fmt:message key="notes.userNotes"/>",
          content: byId("CommentDialog")
      });

      new SimpleTextarea({
        name: "commentText",
        rows: "8",
        cols: "50",
        style: "width:auto;"
      }, "commentText").startup();

      new Button({
          name: "saveButton",
          label: "<fmt:message key="notes.save"/>",
          onClick: saveComment
      }, "saveButton").startup();
  });

  var commentTypeId;
  var commentReferenceId;
  function openCommentDialog(typeId, referenceId) {
      commentTypeId = typeId;
      commentReferenceId = referenceId;
      commentText.value="";
      userCommentDialog.show();
      commentText.focus();
  }

  function saveComment() {
      MiscDwr.addUserComment(commentTypeId, commentReferenceId, commentText.value, saveCommentCB);
  }

  function saveCommentCB(comment) {
      if (!comment)
          alert("<fmt:message key="notes.enterComment"/>");
      else {
          userCommentDialog.hide();

          // Add a row for the comment by cloning the template.
          var content = byId("comment_TEMPLATE_").cloneNode(true);
          updateTemplateNode(content, comment.ts);
          var commentsNode;
          if (commentTypeId == <%= UserComment.TYPE_EVENT %>)
              commentsNode = byId("eventComments"+ commentReferenceId);
          else if (commentTypeId == <%= UserComment.TYPE_POINT %>)
              commentsNode = byId("pointComments"+ commentReferenceId);
          commentsNode.appendChild(content);
          byId("comment"+ comment.ts +"UserTime").innerHTML = comment.prettyTime +" <fmt:message key="notes.by"/> "+ comment.username;
          byId("comment"+ comment.ts +"Text").innerHTML = comment.comment;
      }
  }
</script>

<div style="display:none">
  <div id="CommentDialog" bgColor="white" bgOpacity="0.5" toggle="fade" toggleDuration="250">
    <span class="smallTitle"><fmt:message key="notes.addNote"/></span>
    <table>
      <tr>
        <td><textarea id="commentText"></textarea></td>
      </tr>
      <tr>
        <td>
          <div class="dijitDialogPaneActionBar">
            <button id="saveButton"></button>
          </div>
        </td>
      </tr>
    </table>
  </div>
</div>

<table style="display:none;">
  <tr id="comment_TEMPLATE_">
    <td valign="top" width="16"><tag:img png="comment" title="notes.note"/></td>
    <td valign="top">
      <span id="comment_TEMPLATE_UserTime" class="copyTitle"><fmt:message key="notes.timeByUsername"/></span><br/>
      <span id="comment_TEMPLATE_Text"></span>
    </td>
  </tr>
</table>