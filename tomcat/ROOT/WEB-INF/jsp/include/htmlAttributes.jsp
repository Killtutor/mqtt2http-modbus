<!-- (C) 2013-2014 Alejandro González. All rights reserved. -->
<html>
<head>
<title><%= title %> Attributes</title>
<link rel="icon" type="image/ico" href="icons/favicon.ico" />
<% if (!plain) { %>
<link rel="stylesheet" href="./resources/tree.css" />
<script src="//code.jquery.com/jquery-2.1.1.min.js" type="text/javascript"></script>
<script src="./lib/jstree/jquery.jstree.js" type="text/javascript"></script>
<script src="./lib/jquery.hotkeys.js" type="text/javascript"></script>
<script src="./lib/jquery.cookie.min.js" type="text/javascript"></script>
<script src="./resources/tree.js" type="text/javascript"></script>
<% } %>
<% if (!plain) { %>
<script type="text/javascript">
    $(function() {
        var config = {
            ajax: <%= ajax %>,
            customNode: <%= customNode %>,
            lists: <%= lists %>,
            maps: <%= maps %>,
            methods: <%= methods %>,
            maxlevel: <%= maxlevel %>,
            nodePath: <%= nodePath != null ? '"' + ContextExplorer.escapeJsonString(nodePath) + '"' : null %>,
            noicons: <%= noicons %>,
            openall: <%= openall %>,
            remember: <%= openall %>,
            scope: <%= scope %>,
            sort: <%= sort %>,
            parentNodePath: <%= parentNodePath != null ? '"' + ContextExplorer.escapeJsonString(parentNodePath) + '"' : null %>
        };
        tree.init(config);
    });
</script>
<% } %>
</head>
<body>
<div id="container"><ul>
<%
    if (!ajax) {
        ContextExplorer.printHtmlTree(map, out, remember);
    }
%>
</ul></div>
</body>
</html>
