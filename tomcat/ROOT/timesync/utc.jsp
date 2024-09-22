<%@page import="java.text.SimpleDateFormat"%><%@page import="java.util.Date"%><%@page import="java.util.TimeZone"%><%
final Date currentTime = new Date();
final SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssZ");
sdf.setTimeZone(TimeZone.getTimeZone("UTC"));
out.print(sdf.format(currentTime));
%>