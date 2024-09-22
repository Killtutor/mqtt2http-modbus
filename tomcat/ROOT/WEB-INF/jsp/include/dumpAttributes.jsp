<%-- (C) 2013-2014 Alejandro González. All rights reserved. --%>
<%@ page import="java.util.regex.*" %>
<%@ page import="java.util.*" %>
<%@ page import="ve.com.omega32.*" %>
<%
    // READ OPTIONS
    Boolean plain = (request.getParameter("flat") != null);
    Boolean sort = (request.getParameter("nosort") == null);
    Boolean noicons = (request.getParameter("noicons") != null);
    Boolean customNode = (request.getParameter("node") != null);
    Boolean lists = (request.getParameter("nolists") == null);
    Boolean maps = (request.getParameter("nomaps") == null);
    Boolean arrays = (request.getParameter("noarrays") == null);
    Boolean ajax = (request.getParameter("ajax") != null);
    Boolean json = (request.getParameter("json") != null);
    Boolean jsont = (request.getParameter("jsont") != null);
    Boolean openall = (request.getParameter("openall") != null);
    Boolean remember = (request.getParameter("remember") != null);
    Boolean onlychildren = (request.getParameter("onlychildren") != null);
    Boolean methods = (request.getParameter("methods") != null);

    String nodePath = null;
    String parentNodePath = null;
    if (customNode) {
        nodePath = request.getParameter("node");

        // Eliminar último token del path. Si no se cumple el regex, no se asigna valor a "parentNodePath" (hay un sólo token y no tiene parent).
        Pattern regex = Pattern.compile("(.*)(?: [^ ]+)+");
        Matcher regexMatcher = regex.matcher(nodePath);
        if (regexMatcher.find()) {
            parentNodePath = regexMatcher.group(1);
        }
    }

    Integer maxlevel;
    try {
        maxlevel = Integer.parseInt(request.getParameter("maxlevel"));
    }
    catch (NumberFormatException ex) {
        maxlevel = 6;
    }

    // SET CONTENT TYPE
    String contentType;
    if (json || jsont) {
        contentType = "application/json; charset=UTF-8";
    }
    else {
        contentType = "text/html; charset=UTF-8";
    }
    response.setHeader("Content-Type", contentType);

    // CREATE MAP
    Map<String,ContextExplorer.Node> map = null;
    if (json || jsont || !ajax) {
        ContextExplorer.Config myConfig = new ContextExplorer.Config();
        myConfig.arrays = arrays;
        myConfig.methods = methods;
        myConfig.lists = lists;
        myConfig.maps = maps;
        myConfig.maxlevel = maxlevel;
        myConfig.onlychildren = onlychildren;
        myConfig.sort = sort;
        map = ContextExplorer.buildMap(nodePath, scope, pageContext, myConfig);
    }

    // CLEAN UP
    out.clear(); // limpia todas las líneas vacías generadas hasta ahora

    // PRINT
    if (jsont) {
        ContextExplorer.printTreeJsonNodes(map, out, 0, remember, "");
    }
    else if (json) {
        ContextExplorer.printJsonNodes(map, out);
    }
    else {
        %><%@ include file="/WEB-INF/jsp/include/htmlAttributes.jsp" %><%
    }
%>
