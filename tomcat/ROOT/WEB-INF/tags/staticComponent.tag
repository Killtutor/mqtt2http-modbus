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

--%><%@include file="/WEB-INF/tags/decl.tagf"%><%--
--%><%@tag body-content="empty"%><%--
--%><%@attribute name="vc" type="com.serotonin.mango.view.component.ViewComponent" required="true" rtexprvalue="true"%>
<c:choose>
  <c:when test="${!vc.visible}"><!-- vc ${vc.id} not visible --></c:when>
  <c:otherwise>
    <c:if test="${vc.defName != 'javascript'}">
      <div style="${vc.style}">${vc.staticContent}</div>
    </c:if>
    <c:if test="${!empty vc.clientSideScript}">
      <c:set var="vc" value="${vc}" scope="request"/>
      <jsp:include page="/WEB-INF/jsp/scripts/${vc.clientSideScript}.jsp"/>
    </c:if>
  </c:otherwise>
</c:choose>
