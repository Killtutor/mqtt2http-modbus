<%--
    Copyright (C) 2014-2015 Vemetris. All rights reserved.
    Author: Alejandro Gonzalez

    Syntax:
    /webapi/public/TriggerPublisherSnapshot?id=publisher_id

--%><%@ page contentType="application/json; charset=UTF-8" %><%--
--%><%@ page import="com.serotonin.mango.Common" %><%--
--%><%@ page import="com.serotonin.mango.rt.publish.PublisherRT" %><%--
--%><%@ page import="com.serotonin.mango.rt.RuntimeManager" %><%--
--%><%@ page import="org.apache.commons.lang3.StringEscapeUtils" %><%--
--%><%

boolean success = false;
String message = "";
boolean apiEnabled = Common.getEnvironmentProfile().getBoolean("api.public.events", false);

if (apiEnabled) {
    try {
        String idString = request.getParameter("id");
        if (idString == null) {
            message = "required parameter missing";
        }
        else {
            try {
                int id = Integer.parseInt(idString);
                PublisherRT<?> publisher = ((RuntimeManager)(pageContext.getAttribute("RUNTIME_MANAGER", pageContext.APPLICATION_SCOPE))).getRunningPublisher(id);
                if (publisher != null) {
                    success = publisher.triggerSnapshot();
                }
                else {
                    message = "publisher not found or not running";
                }
            }
            catch(NumberFormatException e) {
                message = "invalid parameter";
            }
        }
    }
    catch (Exception e) {
        message = e.getMessage();
    }
}
else {
    message = "access denied";
}

%>{"success": <%=success%><%= success ? "" : ", \"message\": \"" + StringEscapeUtils.escapeJson(message) + '"'%>}