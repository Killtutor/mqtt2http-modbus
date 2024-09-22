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
<%@page import="com.serotonin.mango.view.ShareUser"%>
<tag:page dwr="ViewDwr" js="view">
<jsp:attribute name="subtitle">
  <fmt:message key="header.views"/>
</jsp:attribute>
<jsp:body>
  <script type="text/javascript" src="resources/lib/wz_jsgraphics.js"></script>
  <script type="text/javascript">
  mango.share.dwr = ViewDwr;
    <c:if test="${!empty currentView}">
      mango.view.initNormalView();

      <c:if test="${owner}">
      ViewDwr.editInit(function(result) {
        mango.share.users = result.shareUsers;
        mango.share.writeSharedUsers(result.viewUsers);
      });
      </c:if>

      dojo.addOnLoad(function(){
          hide("hourglass");
          show("viewContent");
      });
    </c:if>

    function unshare() {
        ViewDwr.deleteViewShare(function() { window.location = 'views.shtm'; });
    }

    function closeUsers(){
        ViewDwr.saveViewUsers();
        hideLayer('usersEdit');
    }
  </script>

  <table style="width: 100%;" cellspacing="0" cellpadding="0">
    <tr>
      <td>
        <table class="borderDiv">
          <tr>
            <td class="smallTitle"><fmt:message key="views.title"/> <tag:help id="graphicalViews"/></td>
            <td width="50"></td>
            <td align="right">
              <sst:select value="${currentView.id}" onchange="window.location='?viewId='+ this.value;">
                <c:forEach items="${views}" var="aView">
                  <sst:option value="${aView.key}">${sst:escapeLessThan(aView.value)}</sst:option>
                </c:forEach>
              </sst:select>
              <c:if test="${!empty currentView}">
                <c:if test="${owner}">
                  <tag:img png="user" title="share.sharing" onclick="showLayer('usersEdit',4,12)"/>
                    <div id="usersEdit" style="visibility:hidden" class="labelDiv">
                      <tag:sharedUsers doxId="viewSharing" noUsersKey="share.noViewUsers" closeFunction="closeUsers()"/>
                    </div>
                </c:if>
                <c:if test="${sessionUser.superAdmin}">
                  <a href="view_edit.shtm?viewId=${currentView.id}"><tag:img png="icon_view_edit" title="viewEdit.editView"/></a>
                </c:if>
              </c:if>
              <c:if test="${sessionUser.superAdmin}">
                <a href="view_edit.shtm"><tag:img png="icon_view_new" title="views.newView"/></a>
              </c:if>
            </td>
          </tr>
        </table>
      </td>
    </tr>
    <tr>
      <td>
        <table style="margin: 0px auto;">
          <tr>
            <td>
              <tag:displayView view="${currentView}" emptyMessageKey="views.noViews"/>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</jsp:body>
</tag:page>
<%@ include file="/WEB-INF/jsp/include/pointEventDetectors.jsp" %>