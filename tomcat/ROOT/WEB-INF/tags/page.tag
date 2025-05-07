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
<!DOCTYPE html>
<%@include file="/WEB-INF/tags/decl.tagf"%>
<%@attribute name="styles" fragment="true" %>
<%@attribute name="dwr" %>
<%@attribute name="js" %>
<%@attribute name="onload" %>
<%@attribute name="subtitle" %>

<html>
<head>
  <title>
    <c:choose>
      <c:when test="${!empty instanceDescription}">${instanceDescription}</c:when>
      <c:otherwise><fmt:message key="header.title"/></c:otherwise>
    </c:choose>
    <c:if test="${!empty subtitle}"> | ${fn:toLowerCase(subtitle)}</c:if>
  </title>

  <!-- Meta -->
  <meta http-equiv="content-type" content="application/xhtml+xml;charset=utf-8"/>
  <meta http-equiv="Content-Style-Type" content="text/css" />
  <meta name="Copyright" content="&copy;2014 Vemetris"/>
  <meta name="DESCRIPTION" content="Vemetris"/>
  <meta name="KEYWORDS" content="Vemetris"/>

  <!-- Style -->
  <link rel="icon" href="images/favicon_01.ico"/>
  <link rel="shortcut icon" href="images/favicon_01.ico"/>
  <link href="resources/common.css" type="text/css" rel="stylesheet"/>
  <link href="resources/custom.css" type="text/css" rel="stylesheet"/>
  <link rel="stylesheet" href="resources/dojo-release-1.10.0/dijit/themes/claro/claro.css">
  <jsp:invoke fragment="styles"/>

  <!-- Scripts -->
  <script>dojoConfig = {async: false, parseOnLoad: true, locale: '${lang}'}</script>
  <script type="text/javascript" src="resources/dojo-release-1.10.0/dojo/dojo.js"></script>
  <script type="text/javascript" src="resources/jquery/jquery.min.js"></script>
  <script type="text/javascript" src="resources/jquery/jquery.blockUI.js"></script>
  <script type="text/javascript" src="dwr/engine.js"></script>
  <script type="text/javascript" src="dwr/util.js"></script>
  <script type="text/javascript" src="dwr/interface/MiscDwr.js"></script>
  <script type="text/javascript" src="resources/soundmanager/soundmanager2-nodebug-jsmin.js"></script>
  <script type="text/javascript" src="resources/common.js"></script>
  <script type="text/javascript" src="resources/errorAlert.js"></script>
  <script type="text/javascript" src="resources/custom.js"></script>
  <c:forEach items="${dwr}" var="dwrname">
    <script type="text/javascript" src="dwr/interface/${dwrname}.js"></script></c:forEach>
  <c:forEach items="${js}" var="jsname">
    <script type="text/javascript" src="resources/${jsname}.js"></script></c:forEach>
  <script type="text/javascript">
    mango.i18n = <sst:convert obj="${clientSideMessages}"/>;
  </script>
  <c:if test="${!simple}">
    <script type="text/javascript" src="resources/header.js"></script>
    <script type="text/javascript">
      dwr.util.setEscapeHtml(false);
      <c:if test="${!empty sessionUser}">
          require(["dojo/ready"], function(ready){
              ready(mango.header.onLoad);
              ready(function(){ setUserMuted(${sessionUser.muted}); });
          });
      </c:if>

      function setLocale(locale) {
          MiscDwr.setLocale(locale, function() { window.location = window.location });
      }

      function setHomeUrl() {
          MiscDwr.setHomeUrl(window.location.href, function() { alert("Home URL saved"); });
      }

      function goHomeUrl() {
          MiscDwr.getHomeUrl(function(loc) { window.location = loc; });
      }
    </script>
  </c:if>
</head>

<body class="claro">
  <header>
    <div id="fixedHeader">
      <div id="fixedHeaderC1">
        <span class="smallTitle">${instanceDescription}</span>
      </div>

      <c:if test="${!simple}">
        <div id="fixedHeaderC2">
          <c:if test="${!empty sessionUser}">
            <a href="events.shtm">
              <span id="__header__alarmLevelDiv" style="display:none;">
                <img id="__header__alarmLevelImg" src="images/spacer.gif" alt="" border="0" title=""/>
              <span id="__header__alarmLevelText"></span>
              </span>
            </a>
          </c:if>
        </div>
      </c:if>

      <div id="fixedHeaderC3">
        <c:if test="${!empty sessionUser}">
          <span class="smallTitle"><fmt:message key="header.user"/>: ${sessionUser.username}</span>
          <tag:img id="userMutedImg" onclick="MiscDwr.toggleUserMuted(setUserMuted)" onmouseover="hideLayer('localeEdit')"/>
          <tag:img png="house" title="header.goHomeUrl" onclick="goHomeUrl()" onmouseover="hideLayer('localeEdit')"/>
          <tag:img png="house_link" title="header.setHomeUrl" onclick="setHomeUrl()" onmouseover="hideLayer('localeEdit')"/>
        </c:if>
        <div style="display:inline;" onmouseover="showMenu('localeEdit', -50, 10);">
          <tag:img png="world" title="header.changeLanguage"/>
          <div id="localeEdit" style="visibility:hidden;" class="labelDiv" onmouseout="hideLayer(this)">
            <c:forEach items="${availableLanguages}" var="lang">
              <a class="ptr" onclick="setLocale('${lang.key}')">${lang.value}</a><br/>
            </c:forEach>
          </div>
        </div>
      </div>
    </div>

    <div id="fixedHeaderBack"></div>

    <div id="mainHeader">
      <img id="mainLogo" src="images/logo_UCV2.svg" alt="Logo"/>
      <img id="mainLogo" src="images/logo_FIUCV.svg" alt="Logo"/>
      <img id="mainLogo" src="images/logo_eie.png" alt="Logo"/>
    </div>

    <c:if test="${!simple}">
      <nav id="navBar" style="min-width:800px;">
        <ul>
          <c:if test="${!empty sessionUser}">
            <li><tag:menuItem href="watch_list.shtm" png="eye_32" key="header.watchlist"/></li>
            <li><tag:menuItem href="views.shtm" png="icon_view_32" key="header.views"/></li>
            <li><tag:menuItem href="events.shtm" png="flag_white_32" key="header.alarms"/></li>

            <c:if test="${sessionUser.admin}">
              <li><img src="images/menu_separator_32.png"/></li>
              <li><tag:menuItem href="reports.shtm" png="report_32" key="header.reports"/></li>
              <li><tag:menuItem href="mailing_lists.shtm" png="book_32" key="header.mailingLists"/></li>
              <li><tag:menuItem href="text_gateways.shtm" png="phone_32" key="header.textGateways"/></li>
            </c:if>

            <c:if test="${sessionUser.superAdmin}">
              <li><tag:menuItem href="phones_lists.shtm" png="book_32_green" key="header.phonesLists"/></li>
              <li><img src="images/menu_separator_32.png"/></li>
              <li><tag:menuItem href="data_sources.shtm" png="icon_ds_32" key="header.dataSources"/></li>
              <li><tag:menuItem href="point_hierarchy.shtm" png="folder_brick_32" key="header.pointHierarchy"/></li>
              <li><tag:menuItem href="point_links.shtm" png="link_32" key="header.pointLinks"/></li>
              <li><tag:menuItem href="publishers.shtm" png="transmit_32" key="header.publishers"/></li>
              <li><tag:menuItem href="event_handlers.shtm" png="cog_32" key="header.eventHandlers"/></li>
              <li><tag:menuItem href="scheduled_events.shtm" png="clock_32" key="header.scheduledEvents"/></li>
              <li><tag:menuItem href="compound_events.shtm" png="multi_bell_32" key="header.compoundEvents"/></li>
              <li><img src="images/menu_separator_32.png"/></li>
              <li><tag:menuItem href="emport.shtm" png="script_code_32" key="header.emport"/></li>
              <li><tag:menuItem href="sql.shtm" png="script_32" key="header.sql"/></li>
            </c:if>

            <c:if test="${sessionUser.admin && !sessionUser.superAdmin}">
              <li><img src="images/menu_separator_32.png"/></li>
            </c:if>

            <c:if test="${sessionUser.admin}">
              <li><tag:menuItem href="maintenance_events.shtm" png="hammer_32" key="header.maintenanceEvents"/></li>
              <li><tag:menuItem href="system_settings.shtm" png="application_form_32" key="header.systemSettings"/></li>
            </c:if>

            <li><img src="images/menu_separator_32.png"/></li>
            <li><tag:menuItem href="users.shtm" png="user_32" key="header.users"/></li>
            <li><tag:menuItem href="help.shtm" png="help_32" key="header.help"/></li>
            <li><tag:menuItem href="logout.htm" png="exit_32" key="header.logout"/></li>
            <div id="headerMenuDescription" class="labelDiv" style="position:absolute;display:none;"></div>
          </c:if>
        </ul>
      </nav>
    </c:if>
  </header>

  <article>
    <jsp:doBody/>
  </article>

  <footer>
    <div class="footer">
      <div>&copy;2014 Vemetris - <fmt:message key="footer.rightsReserved"/></div>
      <div style="display:table;padding-top:3px;">
        <div style="display:table-cell;vertical-align:middle;padding-right:3px;"><fmt:message key="footer.poweredBy"/></div>
        <div style="display:table-cell;vertical-align:middle;"><a href="http://www.vemetris.com/"><img src="images/vemetris_logo68x24.png" alt="Vemetris"/></a></div>
      </div>
    </div>
  </footer>

  <c:if test="${!empty onload}">
    <script type="text/javascript">
        require(["dojo/ready"], function(ready){
            ready(${onload});
        });
    </script>
  </c:if>
</body>
</html>
