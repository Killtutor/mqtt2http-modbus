<%--
    Copyright (C) 2014-2015 Vemetris. All rights reserved.
    Author: Alejandro Gonzalez

    Syntax:
    /webapi/public/GetMaxAlarmLevel[?option1=value[&optionN=value]]

    Options:
    · active   = {yes|no|both}  [default=yes]
    · pending  = {yes|no|both}  [default=yes]

--%><%@ page contentType="application/json; charset=UTF-8" %><%--
--%><%@ page import="com.serotonin.mango.db.dao.EventDao" %><%--
--%><%@ page import="com.serotonin.mango.Common" %><%--
--%><%@ page import="org.apache.commons.lang3.StringEscapeUtils" %><%--
--%><%
boolean success = false;
int maxAlarmLevel = 0;
String message = "";

boolean apiEnabled = Common.getEnvironmentProfile().getBoolean("api.public.events", false);

if (apiEnabled) {
    try {
        String activeStr = request.getParameter("active");
        Boolean active = true;
        if (activeStr == null) {
        }
        else if (activeStr.equals("no")) {
            active = false;
        }
        else if (activeStr.equals("both")) {
            active = null;
        }

        String pendingParam = request.getParameter("pending");
        Boolean pending = true;
        if (pendingParam == null) {
        }
        else if (pendingParam.equals("no")) {
            pending = false;
        }
        else if (pendingParam.equals("both")) {
            pending = null;
        }

        EventDao eventDao = new EventDao();
        maxAlarmLevel = eventDao.getHighestAlarmLevel(active, pending);
        success = true;
    }
    catch (Exception e) {
        message = e.getMessage();
    }
}
else {
    message = "access denied";
}

%>{"success": <%=success%><%= success ? ", \"maxAlarmLevel\": " + maxAlarmLevel : ", \"message\": \"" + StringEscapeUtils.escapeJson(message) + '"'%>}