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
<div class="borderDiv marB marR">
  <table>
    <tr><td colspan="3">
      <span class="smallTitle"><fmt:message key="pointEdit.text.props"/></span>
      <tag:help id="textRenderers"/>
    </td></tr>

    <tr>
      <td class="formLabelRequired"><fmt:message key="pointEdit.text.type"/></td>
      <td class="formField">
        <sst:select id="textRendererSelect" onchange="textRendererEditor.change();"
                value="${form.textRenderer.typeName}">
          <c:forEach items="${textRenderers}" var="trdef">
            <sst:option value="${trdef.name}"><fmt:message key="${trdef.nameKey}"/></sst:option>
          </c:forEach>
        </sst:select>
      </td>
    </tr>

    <tbody id="textRendererAnalog" style="display:none;">
      <tr>
        <td class="formLabelRequired"><fmt:message key="pointEdit.text.format"/></td>
        <td class="formField">
          <input id="textRendererAnalogFormat" type="text"/>
          <tag:help id="numberFormats"/>
        </td>
      </tr>
      <tr>
        <td class="formLabel"><fmt:message key="pointEdit.text.suffix"/></td>
        <td class="formField"><input id="textRendererAnalogSuffix" type="text"/></td>
      </tr>
    </tbody>
    <tbody id="textRendererBinary" style="display:none;">
      <tr>
        <td class="formLabelRequired"><fmt:message key="pointEdit.text.zero"/></td>
        <td class="formField">
          <table cellspacing="0" cellpadding="0">
            <tr>
              <td valign="top"><input id="textRendererBinaryZero" type="text"/></td>
              <td width="10"></td>
              <td valign="top" align="center">
                <div data-dojo-type="dijit/ColorPalette" id="textRendererBinaryZeroColour" data-dojo-props="onChange:textRendererEditor.handlerBinaryZeroColour"></div>
                <br><a href="#" onclick="dijit.byId('textRendererBinaryZeroColour').set('value',null); return false;">(<fmt:message key="pointEdit.text.default"/>)</a>
              </td>
            </tr>
          </table>
        </td>
      </tr>
      <tr>
        <td class="formLabelRequired"><fmt:message key="pointEdit.text.one"/></td>
        <td class="formField">
          <table cellspacing="0" cellpadding="0">
            <tr>
              <td valign="top"><input id="textRendererBinaryOne" type="text"/></td>
              <td width="10"></td>
              <td valign="top" align="center">
                <div data-dojo-type="dijit/ColorPalette" id="textRendererBinaryOneColour" data-dojo-props="onChange:textRendererEditor.handlerBinaryOneColour"></div>
                <br><a href="#" onclick="dijit.byId('textRendererBinaryOneColour').set('value',null); return false;">(<fmt:message key="pointEdit.text.default"/>)</a>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </tbody>
    <tbody id="textRendererMultistate" style="display:none;">
      <tr>
        <td colspan="2">
          <table>
            <tr>
              <th><fmt:message key="pointEdit.text.key"/></th>
              <th><fmt:message key="pointEdit.text.text"/></th>
              <th><fmt:message key="pointEdit.text.colour"/></th>
              <td></td>
            </tr>
            <tr>
              <td valign="top"><input type="text" id="textRendererMultistateKey" value="" class="formVeryShort"/></td>
              <td valign="top"><input type="text" id="textRendererMultistateText" value="" class="formShort"/></td>
              <td valign="top" align="center">
                <div data-dojo-type="dijit/ColorPalette" id="textRendererMultistateColour" data-dojo-props="onChange:textRendererEditor.handlerMultistateColour"></div>
                <br><a href="#" onclick="dijit.byId('textRendererMultistateColour').set('value',null); return false;">(<fmt:message key="pointEdit.text.default"/>)</a>
              </td>
              <td valign="top">
                <tag:img png="add" title="common.add" onclick="return textRendererEditor.addMultistateValue();"/>
              </td>
            </tr>
            <tbody id="textRendererMultistateTable"></tbody>
          </table>
        </td>
      </tr>
    </tbody>
    <tbody id="textRendererNone" style="display:none;">
    </tbody>
    <tbody id="textRendererPlain" style="display:none;">
      <tr>
        <td class="formLabel"><fmt:message key="pointEdit.text.suffix"/></td>
        <td class="formField"><input id="textRendererPlainSuffix" type="text"/></td>
      </tr>
    </tbody>
    <tbody id="textRendererRange" style="display:none;">
      <tr>
        <td class="formLabelRequired"><fmt:message key="pointEdit.text.format"/></td>
        <td class="formField"><input id="textRendererRangeFormat" type="text"/></td>
      </tr>
      <tr>
        <td colspan="2">
          <table>
            <tr>
              <th><fmt:message key="pointEdit.text.from"/></th>
              <th><fmt:message key="pointEdit.text.to"/></th>
              <th><fmt:message key="pointEdit.text.text"/></th>
              <th><fmt:message key="pointEdit.text.colour"/></th>
              <td></td>
            </tr>
            <tr>
              <td valign="top"><input type="text" id="textRendererRangeFrom" value="" class="formVeryShort"/></td>
              <td valign="top"><input type="text" id="textRendererRangeTo" value="" class="formVeryShort"/></td>
              <td valign="top"><input type="text" id="textRendererRangeText" value=""/></td>
              <td valign="top" align="center">
                <div data-dojo-type="dijit/ColorPalette" id="textRendererRangeColour" data-dojo-props="onChange:textRendererEditor.handlerRangeColour"></div>
                <br><a href="#" onclick="dijit.byId('textRendererRangeColour').set('value',null); return false;">(<fmt:message key="pointEdit.text.default"/>)</a>
              </td>
              <td valign="top">
                <tag:img png="add" title="common.add" onclick="return textRendererEditor.addRangeValue();"/>
              </td>
            </tr>
            <tbody id="textRendererRangeTable"></tbody>
          </table>
        </td>
      </tr>
    </tbody>
    <tbody id="textRendererTime" style="display:none;">
      <tr>
        <td class="formLabelRequired"><fmt:message key="pointEdit.text.format"/></td>
        <td class="formField">
          <input id="textRendererTimeFormat" type="text"/>
          <tag:help id="datetimeFormats"/>
        </td>
      </tr>
      <tr>
        <td class="formLabel"><fmt:message key="pointEdit.text.conversionExponent"/></td>
        <td class="formField"><input id="textRendererTimeConversionExponent" type="text"/></td>
      </tr>
    </tbody>
  </table>
</div>

<script type="text/javascript">
  require(["dojo/parser", "dijit/ColorPalette"]);
  function TextRendererEditor() {
      var currentTextRenderer;
      var multistateValues = new Array();
      var rangeValues = new Array();

      this.init = function() {
          // Figure out which fields to populate with data.
          <c:choose>
            <c:when test='${form.textRenderer.typeName == "textRendererAnalog"}'>
              $set("textRendererAnalogFormat", "${sst:dquotEncode(form.textRenderer.format)}");
              $set("textRendererAnalogSuffix", "${sst:dquotEncode(form.textRenderer.suffix)}");
            </c:when>
            <c:when test='${form.textRenderer.typeName == "textRendererBinary"}'>
              $set("textRendererBinaryZero", "${sst:dquotEncode(form.textRenderer.zeroLabel)}");
              dijit.byId('textRendererBinaryZeroColour').set('value','${sst:dquotEncode(form.textRenderer.zeroColour)}')
              $set("textRendererBinaryOne", "${sst:dquotEncode(form.textRenderer.oneLabel)}");
              dijit.byId('textRendererBinaryOneColour').set('value','${sst:dquotEncode(form.textRenderer.oneColour)}')
            </c:when>
            <c:when test='${form.textRenderer.typeName == "textRendererMultistate"}'>
              <c:forEach items="${form.textRenderer.multistateValues}" var="msValue">
                textRendererEditor.addMultistateValue("${sst:dquotEncode(msValue.key)}",
                        "${sst:dquotEncode(msValue.text)}", "${sst:dquotEncode(msValue.colour)}");
              </c:forEach>
            </c:when>
            <c:when test='${form.textRenderer.typeName == "textRendererNone"}'>
            </c:when>
            <c:when test='${form.textRenderer.typeName == "textRendererPlain"}'>
              $set("textRendererPlainSuffix", "${sst:dquotEncode(form.textRenderer.suffix)}");
            </c:when>
            <c:when test='${form.textRenderer.typeName == "textRendererRange"}'>
              $set("textRendererRangeFormat", "${sst:dquotEncode(form.textRenderer.format)}");
              <c:forEach items="${form.textRenderer.rangeValues}" var="rgValue">
                textRendererEditor.addRangeValue("${rgValue.from}", "${rgValue.to}", "${sst:dquotEncode(rgValue.text)}",
                        "${sst:dquotEncode(rgValue.colour)}");
              </c:forEach>
            </c:when>
            <c:when test='${form.textRenderer.typeName == "textRendererTime"}'>
              $set("textRendererTimeFormat", "${sst:dquotEncode(form.textRenderer.format)}");
              $set("textRendererTimeConversionExponent", "${sst:dquotEncode(form.textRenderer.conversionExponent)}");
            </c:when>
            <c:otherwise>
              dojo.debug("Unknown text renderer: ${form.textRenderer.typeName}");
            </c:otherwise>
          </c:choose>

          textRendererEditor.change();
      }

      this.change = function() {
          if (currentTextRenderer)
              hide(byId(currentTextRenderer));
          currentTextRenderer = byId("textRendererSelect").value
          show(byId(currentTextRenderer));
      };

      this.save = function(callback) {
          var typeName = $get("textRendererSelect");
          if (typeName == "textRendererAnalog")
              DataPointEditDwr.setAnalogTextRenderer($get("textRendererAnalogFormat"),
                      $get("textRendererAnalogSuffix"), callback);
          else if (typeName == "textRendererBinary")
              DataPointEditDwr.setBinaryTextRenderer($get("textRendererBinaryZero"),
                      dijit.byId("textRendererBinaryZeroColour").value, $get("textRendererBinaryOne"),
                      dijit.byId("textRendererBinaryOneColour").value, callback);
          else if (typeName == "textRendererMultistate")
              DataPointEditDwr.setMultistateRenderer(multistateValues, callback);
          else if (typeName == "textRendererNone")
              DataPointEditDwr.setNoneRenderer(callback);
          else if (typeName == "textRendererPlain")
              DataPointEditDwr.setPlainRenderer($get("textRendererPlainSuffix"), callback);
          else if (typeName == "textRendererRange")
              DataPointEditDwr.setRangeRenderer($get("textRendererRangeFormat"), rangeValues, callback);
          else if (typeName == "textRendererTime")
              DataPointEditDwr.setTimeTextRenderer($get("textRendererTimeFormat"),
                      $get("textRendererTimeConversionExponent"), callback);
          else
              callback();
      };

      //
      // List objects
      this.MultistateValue = function() {
          this.key;
          this.text;
          this.colour;
      };

      this.RangeValue = function() {
          this.from;
          this.to;
          this.text;
          this.colour;
      };

      //
      // Multistate list manipulation
      this.addMultistateValue = function(theKey, text, colour) {
          if (!theKey)
              theKey = $get("textRendererMultistateKey");
          var theNumericKey = parseInt(theKey);
          if (isNaN(theNumericKey)) {
              alert("<fmt:message key="pointEdit.text.errorParsingKey"/>");
              return false;
          }
          for (var i=multistateValues.length-1; i>=0; i--) {
              if (multistateValues[i].key == theNumericKey) {
                  alert("<fmt:message key="pointEdit.text.listContainsKey"/> "+ theNumericKey);
                  return false;
              }
          }

          var theValue = new this.MultistateValue();
          theValue.key = theNumericKey;
          if (text)
              theValue.text = text;
          else
              theValue.text = $get("textRendererMultistateText");
          if (colour)
              theValue.colour = colour;
          else
              theValue.colour = dijit.byId("textRendererMultistateColour").value;
          multistateValues[multistateValues.length] = theValue;
          this.sortMultistateValues();
          this.refreshMultistateList();
          $set("textRendererMultistateKey", theNumericKey+1);

          return false;
      };

      this.removeMultistateValue = function(theValue) {
          for (var i=multistateValues.length-1; i>=0; i--) {
              if (multistateValues[i].key == theValue)
                  multistateValues.splice(i, 1);
          }
          this.refreshMultistateList();
          return false;
      };

      this.sortMultistateValues = function() {
          multistateValues.sort( function(a,b) { return a.key-b.key; } );
      };

      this.refreshMultistateList = function() {
          dwr.util.removeAllRows("textRendererMultistateTable");
          dwr.util.addRows("textRendererMultistateTable", multistateValues, [
                  function(data) { return data.key; },
                  function(data) {
                      if (data.colour)
                          return "<span style='color:"+ data.colour +"'>"+ data.text +"</span>";
                      return data.text;
                  },
                  function(data) {
                      return "<a href='#' onclick='return textRendererEditor.removeMultistateValue("+ data.key +
                             ");'><img src='images/bullet_delete.png' width='16' height='16' border='0' "+
                             "title='<fmt:message key="common.delete"/>'/><\/a>";
                  }
                  ], null);
      };

      //
      // Range list manipulation
      this.addRangeValue = function(theFrom, theTo, text, colour) {
          if (!theFrom)
              theFrom = parseFloat($get("textRendererRangeFrom"));
          if (isNaN(theFrom)) {
              alert("<fmt:message key="pointEdit.text.errorParsingFrom"/>");
              return false;
          }

          if (!theTo)
              theTo = parseFloat($get("textRendererRangeTo"));
          if (isNaN(theTo)) {
              alert("<fmt:message key="pointEdit.text.errorParsingTo"/>");
              return false;
          }

          if (isNaN(theTo >= theFrom)) {
              alert("<fmt:message key="pointEdit.text.toGreaterThanFrom"/>");
              return false;
          }

          for (var i=0; i<rangeValues.length; i++) {
              if (rangeValues[i].from == theFrom && rangeValues[i].to == theTo) {
                  alert("<fmt:message key="pointEdit.text.listContainsRange"/> "+ theFrom +" - "+ theTo);
                  return false;
              }
          }

          var theValue = new this.RangeValue();
          theValue.from = theFrom;
          theValue.to = theTo;
          if (text)
              theValue.text = text;
          else
              theValue.text = $get("textRendererRangeText");
          if (colour)
              theValue.colour = colour;
          else
              theValue.colour = dijit.byId("textRendererRangeColour").value;
          rangeValues[rangeValues.length] = theValue;
          this.sortRangeValues();
          this.refreshRangeList();
          $set("textRendererRangeFrom", theTo);
          $set("textRendererRangeTo", theTo + (theTo - theFrom));
          return false;
      };

      this.removeRangeValue = function(theFrom, theTo) {
          for (var i=rangeValues.length-1; i>=0; i--) {
              if (rangeValues[i].from == theFrom && rangeValues[i].to == theTo)
                  rangeValues.splice(i, 1);
          }
          this.refreshRangeList();
          return false;
      };

      this.sortRangeValues = function() {
          rangeValues.sort( function(a,b) {
              if (a.from == b.from)
                  return a.to-b.to;
              return a.from-b.from;
          });
      };

      this.refreshRangeList = function() {
          dwr.util.removeAllRows("textRendererRangeTable");
          dwr.util.addRows("textRendererRangeTable", rangeValues, [
                  function(data) { return data.from; },
                  function(data) { return data.to; },
                  function(data) {
                      if (data.colour)
                          return "<span style='color:"+ data.colour +"'>"+ data.text +"</span>";
                      return data.text;
                  },
                  function(data) {
                      return "<a href='#' onclick='return textRendererEditor.removeRangeValue("+
                             data.from +","+ data.to +");'><img src='images/bullet_delete.png' width='16' "+
                             "height='16' border='0' title='<fmt:message key="common.delete"/>'/><\/a>";
                  }
                  ], null);
      };

      //
      // Color handling
      this.handlerRangeColour = function(colour) {
          byId("textRendererRangeText").style.color = colour;
      };
      this.handlerMultistateColour = function(colour) {
          byId("textRendererMultistateText").style.color = colour;
      };
      this.handlerBinaryZeroColour = function(colour) {
          byId("textRendererBinaryZero").style.color = colour;
      };
      this.handlerBinaryOneColour = function(colour) {
          byId("textRendererBinaryOne").style.color = colour;
      };
  }
  var textRendererEditor = new TextRendererEditor();
  dojo.addOnLoad(textRendererEditor, "init");
</script>