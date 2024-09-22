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
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">

<html>
<head>
  <c:set var="subtitle">
    <fmt:message key="common.publicView"/>
  </c:set>
  <title><c:choose>
    <c:when test="${!empty instanceDescription}">${instanceDescription}</c:when>
    <c:otherwise><fmt:message key="header.title"/></c:otherwise>
  </c:choose> | ${fn:toLowerCase(subtitle)}</title>

  <!-- Style -->
  <link rel="icon" href="images/favicon_01.ico"/>
  <link rel="shortcut icon" href="images/favicon_01.ico"/>
  <link href="resources/common.css" type="text/css" rel="stylesheet"/>

  <!-- Script -->
  <script>dojoConfig = {async: false, parseOnLoad: true}</script>
  <script type="text/javascript" src="resources/dojo-release-1.10.0/dojo/dojo.js"></script>
  <script type="text/javascript" src="resources/jquery/jquery.min.js"></script>
  <script type="text/javascript" src="resources/jquery/jquery.blockUI.js"></script>
  <script type="text/javascript" src="dwr/engine.js"></script>
  <script type="text/javascript" src="dwr/util.js"></script>
  <script type="text/javascript" src="resources/common.js"></script>
  <script type="text/javascript" src="dwr/interface/ViewDwr.js"></script>
  <script type="text/javascript" src="dwr/interface/MiscDwr.js"></script>
  <script type="text/javascript" src="resources/view.js"></script>
  <script type="text/javascript" src="resources/lib/wz_jsgraphics.js"></script>
  <script type="text/javascript" src="resources/header.js"></script>
  <script type="text/javascript">
    try {
        dwr.engine.setErrorHandler(function(){}); <%-- Empty error handler to make sure the default one doesn't issue any alert() commands. Normally, this would be handled by errorAlert.js, but in theory, that file may fail to load. --%>
    } catch (err) {};
  </script>
  <script type="text/javascript" src="resources/errorAlert.js"></script>
</head>

<body style="background-color:transparent">
  <div style="display: table; width: 100%; height: 100%; position: fixed;">
    <div style="display: table-cell; width: 100%; text-align: center; vertical-align: middle;">
      <tag:displayView view="${view}" emptyMessageKey="publicView.notFound"/>
    </div>
  </div>

  <c:if test="${!empty view}">
    <script type="text/javascript">
      mango.i18n = <sst:convert obj="${clientSideMessages}"/>;
      dwr.util.setEscapeHtml(false);
      mango.view.initAnonymousView(${view.id});
      dojo.addOnLoad(mango.longPoll.start);
    </script>
  </c:if>
    <script type="text/javascript">
      dojo.addOnLoad(function(){
          hide("hourglass");
          show("viewContent");
      });
    </script>
</body>
</html>