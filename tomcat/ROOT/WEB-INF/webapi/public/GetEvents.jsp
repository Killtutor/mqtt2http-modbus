<%--
    Copyright (C) 2014-2015 Vemetris. All rights reserved.
    Author: Alejandro Gonzalez

    Syntax:
    /webapi/public/GetEvents[?option1=value[&optionN=value]]

    Options:
    · language = <language tag>
    · active   = {yes|no|both}  [default=yes]
    · pending  = {yes|no|both}  [default=yes]

--%><%@ page contentType="application/json; charset=UTF-8" %><%--
--%><%@ page import="java.text.*,java.util.*" %><%--
--%><%@ page import="java.util.Locale" %><%--
--%><%@ page import="com.serotonin.mango.db.dao.EventDao" %><%--
--%><%@ page import="com.serotonin.mango.rt.event.EventInstance" %><%--
--%><%@ page import="com.serotonin.mango.util.web.i18n.Utf8ResourceBundle" %><%--
--%><%@ page import="com.serotonin.mango.Common" %><%--
--%><%@ page import="ve.org.vemetris.web.SanitazeUtils" %><%--
--%><%@ page import="org.apache.commons.lang3.StringEscapeUtils" %><%--
--%><%@ page import="org.apache.commons.lang3.LocaleUtils" %><%--
--%><%
boolean success = false;
String message = "";
List<EventInstance> eventInstances = null;
String eventsJSON = "";

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
        eventInstances = eventDao.getEvents(active, pending, false);
        eventsJSON += '[';
        if (eventInstances.size() > 0) {
            Locale locale;
            if (request.getParameter("language") != null) {
                String language = SanitazeUtils.Word(request.getParameter("language"), new char[] {'_', '-'});
                locale = LocaleUtils.toLocale(language);
            }
            else {
                locale = Locale.getDefault();
            }
            ResourceBundle bundle = Utf8ResourceBundle.getBundle("messages", locale);

            int last = eventInstances.size() - 1;
            int c = 0;
            for (EventInstance evt : eventInstances) {
                eventsJSON += '{';
                eventsJSON += "\"id\": " + evt.getId();
                eventsJSON += ", \"level\": " + evt.getAlarmLevel();
                eventsJSON += ", \"timestamp\": " + evt.getActiveTimestamp();
                eventsJSON += ", \"message\": \"" + StringEscapeUtils.escapeJson(evt.getMessage().getLocalizedMessage(bundle)) + "\"";
                eventsJSON += '}';
                if (c < last) {
                    eventsJSON += ',';
                }
                c++;
            }
        }
        eventsJSON += ']';
        success = true;
    }
    catch (Exception e) {
        message = e.getMessage();
    }
}
else {
    message = "access denied";
}

%>{"success": <%=success%><%= success ? ", \"events\": " + eventsJSON : ", \"message\": \"" + StringEscapeUtils.escapeJson(message) + '"'%>}