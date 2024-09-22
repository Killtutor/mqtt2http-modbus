<%--
Vemetris - www.vemetris.com
Copyright (C) 20012-2014 Vemetris
@author Andres Ponte
--%>
<%@ include file="/WEB-INF/jsp/include/tech.jsp" %>
<%@page import="com.serotonin.mango.vo.event.PointEventDetectorVO"%>

<style type="text/css">
    .dojoDialog {
        background : #eee;
        border : 1px solid #999;
        -moz-border-radius : 5px;
        padding : 4px;
    }
    #eventsTable .row td {
        vertical-align: top;
    }
    #eventsTable .rowAlt td {
        vertical-align: top;
    }
</style>

<div style="display:none;" id="pd_TEMPLATE_Row">
  <table style="width:100%;">
    <tr>
      <td colspan="3" style="text-align:center;" class="simpleRenderer">
        <label id="pd_TEMPLATE_EventDescription" type="text"/>
      </td>
    </tr>
    <tr>
      <td class="formLabelRequired"><fmt:message key="common.alarmLevel"/></td>
      <td class="formField">
        <select id="pd_TEMPLATE_AlarmLevel" onchange="updateAlarmLevelImage(this.value, getPedId(this))">
          <tag:alarmLevelOptions/>
        </select>
        <tag:img id="pd_TEMPLATE_AlarmLevelImg" png="flag_green" title="common.alarmLevel.none"/>
      </td>
    </tr>
    <tr id="pd_TEMPLATE_HighLimitRow">
      <td class="formLabelRequired" style="min-width:100px;"><fmt:message key="pointEdit.detectors.highLimit"/></td>
      <td class="formField"><input id="pd_TEMPLATE_HighLimit" type="text" class="formShort" value="0"/></td>
    </tr>
    <tr id="pd_TEMPLATE_LowLimitRow">
      <td class="formLabelRequired" style="min-width:100px;"><fmt:message key="pointEdit.detectors.lowLimit"/></td>
      <td class="formField"><input id="pd_TEMPLATE_LowLimit" type="text" class="formShort" value="0"/></td>
    </tr>
    <tr id="pd_TEMPLATE_ChangeCountRow">
      <td class="formLabelRequired" style="min-width:100px;"><fmt:message key="pointEdit.detectors.changeCount"/></td>
      <td class="formField"><input id="pd_TEMPLATE_ChangeCount" type="text" class="formShort" value="0"/></td>
    </tr>
    <tr id="pd_TEMPLATE_PosLimitRow">
      <td class="formLabelRequired" style="min-width:100px;"><fmt:message key="pointEdit.detectors.posLimit"/></td>
      <td class="formField"><input id="pd_TEMPLATE_PosLimit" type="text" class="formShort" value="0"/></td>
    </tr>
    <tr id="pd_TEMPLATE_NegLimitRow">
      <td class="formLabelRequired" style="min-width:100px;"><fmt:message key="pointEdit.detectors.negLimit"/></td>
      <td class="formField"><input id="pd_TEMPLATE_NegLimit" type="text" class="formShort" value="0"/></td>
    </tr>
    <tr id="pd_TEMPLATE_WeightRow">
      <td class="formLabelRequired" style="min-width:100px;"><fmt:message key="pointEdit.detectors.weight"/></td>
      <td class="formField"><input id="pd_TEMPLATE_Weight" type="text" class="formShort" value="0"/></td>
    </tr>
    <tr id="pd_TEMPLATE_DurationRow">
      <td class="formLabelRequired" style="min-width:100px;"><fmt:message key="pointEdit.detectors.duration"/></td>
      <td class="formField"> <input id="pd_TEMPLATE_Duration" type="text" class="formShort"/>
        <sst:select id="pd_TEMPLATE_DurationType" value="0">
          <tag:timePeriodOptions sst="true" s="true" min="true" h="true"/>
        </sst:select>
      </td>
    </tr>
    <tr>
      <td colspan="5" id="pd_TEMPLATE_ErrorMessage"  class="formError"></td>
    </tr>
  </table>
</div>

<div style="display:none;">
  <div id="EventDetectorsDialog" bgColor="white" bgOpacity="0.5" toggle="fade" toggleDuration="250">
    <table style="width:100%;">
      <tr>
        <td>
          <tag:img png="bell" title="pointEdit.detectors.eventDetectors"/>
          <span class="smallTitle"><fmt:message key="pointEdit.detectors.eventDetectors"/></span>
        </td>
      </tr>
      <tr>
        <td>
          <div id="EventDetectorsDialogRow" style="max-height:400px; overflow-y: scroll;" class="borderDiv"/>
        </td>
      <tr>
      <tr>
        <td>
          <div class="dijitDialogPaneActionBar">
            <button data-dojo-type="dijit/form/Button" type="button" onclick="saveEventDetectors();"><fmt:message key="notes.save"/></button>
            <button data-dojo-type="dijit/form/Button" type="button" onclick="pointDetectorsDialog.hide();"><fmt:message key="notes.cancel"/></button>
          </div>
        </td>
      </tr>
    </table>
  </div>
</div>

<script type="text/javascript">
    require(["dijit/form/Button", "dijit/form/Select", "dojo/parser", "dojo/domReady!"]);
    require(["dijit/Dialog", "dojo/domReady!"], function(Dialog){
        pointDetectorsDialog = new Dialog({content: byId("EventDetectorsDialog")});
    });

    function showPointDetectors(pointId, callback){
        var eventDialogRow = byId("EventDetectorsDialogRow");
        eventDialogRow.innerHTML="";

        MiscDwr.getPointDetectors(pointId, function(pointDetectors){
            for(i=0;i<pointDetectors.length;i++){
                var rowContent = createFromTemplate("pd_TEMPLATE_Row", pointDetectors[i].id, eventDialogRow.id);
                rowContent.pedId=pointDetectors[i].id;
                rowContent.pedType=pointDetectors[i].detectorType;

                setAlarmLevelImg(pointDetectors[i].alarmLevel, byId("pd" + pointDetectors[i].id + "AlarmLevelImg"));
                $set("pd"+ pointDetectors[i].id +"AlarmLevel", pointDetectors[i].alarmLevel)

                if(pointDetectors[i].eventDescription.length>0)
                    $set("pd" + pointDetectors[i].id + "EventDescription",pointDetectors[i].eventDescription);

                if (pointDetectors[i].detectorType == <c:out value="<%= PointEventDetectorVO.TYPE_ANALOG_HIGH_LIMIT %>"/>){
                    if(pointDetectors[i].eventDescription.length==0)
                        $set("pd" + pointDetectors[i].id + "EventDescription","<fmt:message key="pointEdit.detectors.highLimitDet"/>");
                    $set("pd" + pointDetectors[i].id + "HighLimit",pointDetectors[i].limit);
                    hide("pd" + pointDetectors[i].id + "LowLimitRow");
                    hide("pd" + pointDetectors[i].id + "ChangeCountRow");
                    hide("pd" + pointDetectors[i].id + "PosLimitRow");
                    hide("pd" + pointDetectors[i].id + "NegLimitRow");
                    hide("pd" + pointDetectors[i].id + "WeightRow");
                    $set("pd" + pointDetectors[i].id + "Duration",pointDetectors[i].duration);
                    $set("pd" + pointDetectors[i].id + "DurationType",pointDetectors[i].durationType);
                }else if(pointDetectors[i].detectorType == <c:out value="<%= PointEventDetectorVO.TYPE_ANALOG_LOW_LIMIT %>"/>){
                    if(pointDetectors[i].eventDescription.length==0)
                        $set("pd" + pointDetectors[i].id + "EventDescription","<fmt:message key="pointEdit.detectors.lowLimitDet"/>");
                    hide("pd" + pointDetectors[i].id + "HighLimitRow");
                    $set("pd" + pointDetectors[i].id + "LowLimit",pointDetectors[i].limit);
                    hide("pd" + pointDetectors[i].id + "ChangeCountRow");
                    hide("pd" + pointDetectors[i].id + "PosLimitRow");
                    hide("pd" + pointDetectors[i].id + "NegLimitRow");
                    hide("pd" + pointDetectors[i].id + "WeightRow");
                    $set("pd" + pointDetectors[i].id + "Duration",pointDetectors[i].duration);
                    $set("pd" + pointDetectors[i].id + "DurationType",pointDetectors[i].durationType);
                }else if(pointDetectors[i].detectorType == <c:out value="<%= PointEventDetectorVO.TYPE_BINARY_STATE %>"/>){
                    if(pointDetectors[i].eventDescription.length==0)
                        $set("pd" + pointDetectors[i].id + "EventDescription","<fmt:message key="pointEdit.detectors.stateDet"/>");
                    hide("pd" + pointDetectors[i].id + "HighLimitRow");
                    hide("pd" + pointDetectors[i].id + "LowLimitRow");
                    hide("pd" + pointDetectors[i].id + "ChangeCountRow");
                    hide("pd" + pointDetectors[i].id + "PosLimitRow");
                    hide("pd" + pointDetectors[i].id + "NegLimitRow");
                    hide("pd" + pointDetectors[i].id + "WeightRow");
                    $set("pd" + pointDetectors[i].id + "Duration",pointDetectors[i].duration);
                    $set("pd" + pointDetectors[i].id + "DurationType",pointDetectors[i].durationType);
                }else if(pointDetectors[i].detectorType == <c:out value="<%= PointEventDetectorVO.TYPE_MULTISTATE_STATE %>"/>){
                    if(pointDetectors[i].eventDescription.length==0)
                        $set("pd" + pointDetectors[i].id + "EventDescription","<fmt:message key="pointEdit.detectors.stateDet"/>");
                    hide("pd" + pointDetectors[i].id + "HighLimitRow");
                    hide("pd" + pointDetectors[i].id + "LowLimitRow");
                    hide("pd" + pointDetectors[i].id + "ChangeCountRow");
                    hide("pd" + pointDetectors[i].id + "PosLimitRow");
                    hide("pd" + pointDetectors[i].id + "NegLimitRow");
                    hide("pd" + pointDetectors[i].id + "WeightRow");
                    $set("pd" + pointDetectors[i].id + "Duration",pointDetectors[i].duration);
                    $set("pd" + pointDetectors[i].id + "DurationType",pointDetectors[i].durationType);
                }else if(pointDetectors[i].detectorType == <c:out value="<%= PointEventDetectorVO.TYPE_POINT_CHANGE %>"/>){
                    if(pointDetectors[i].eventDescription.length==0)
                        $set("pd" + pointDetectors[i].id + "EventDescription","<fmt:message key="pointEdit.detectors.changeDet"/>");
                    hide("pd" + pointDetectors[i].id + "HighLimitRow");
                    hide("pd" + pointDetectors[i].id + "LowLimitRow");
                    hide("pd" + pointDetectors[i].id + "ChangeCountRow");
                    hide("pd" + pointDetectors[i].id + "PosLimitRow");
                    hide("pd" + pointDetectors[i].id + "NegLimitRow");
                    hide("pd" + pointDetectors[i].id + "WeightRow");
                    hide("pd" + pointDetectors[i].id + "DurationRow");
                }else if(pointDetectors[i].detectorType == <c:out value="<%= PointEventDetectorVO.TYPE_STATE_CHANGE_COUNT %>"/>){
                    if(pointDetectors[i].eventDescription.length==0)
                        $set("pd" + pointDetectors[i].id + "EventDescription","<fmt:message key="pointEdit.detectors.changeCounter"/>");
                    hide("pd" + pointDetectors[i].id + "HighLimitRow");
                    hide("pd" + pointDetectors[i].id + "LowLimitRow");
                    $set("pd" + pointDetectors[i].id + "ChangeCount",pointDetectors[i].limit);
                    hide("pd" + pointDetectors[i].id + "PosLimitRow");
                    hide("pd" + pointDetectors[i].id + "NegLimitRow");
                    hide("pd" + pointDetectors[i].id + "WeightRow");
                    hide("pd" + pointDetectors[i].id + "DurationRow");
                }else if(pointDetectors[i].detectorType == <c:out value="<%= PointEventDetectorVO.TYPE_NO_CHANGE %>"/>){
                    if(pointDetectors[i].eventDescription.length==0)
                        $set("pd" + pointDetectors[i].id + "EventDescription","<fmt:message key="pointEdit.detectors.noChange"/>");
                    hide("pd" + pointDetectors[i].id + "HighLimitRow");
                    hide("pd" + pointDetectors[i].id + "LowLimitRow");
                    hide("pd" + pointDetectors[i].id + "ChangeCountRow");
                    hide("pd" + pointDetectors[i].id + "PosLimitRow");
                    hide("pd" + pointDetectors[i].id + "NegLimitRow");
                    hide("pd" + pointDetectors[i].id + "WeightRow");
                    $set("pd" + pointDetectors[i].id + "Duration",pointDetectors[i].duration);
                    $set("pd" + pointDetectors[i].id + "DurationType",pointDetectors[i].durationType);
                }else if(pointDetectors[i].detectorType == <c:out value="<%= PointEventDetectorVO.TYPE_NO_UPDATE %>"/>){
                    if(pointDetectors[i].eventDescription.length==0)
                        $set("pd" + pointDetectors[i].id + "EventDescription","<fmt:message key="pointEdit.detectors.noUpdate"/>");
                    hide("pd" + pointDetectors[i].id + "HighLimitRow");
                    hide("pd" + pointDetectors[i].id + "LowLimitRow");
                    hide("pd" + pointDetectors[i].id + "ChangeCountRow");
                    hide("pd" + pointDetectors[i].id + "PosLimitRow");
                    hide("pd" + pointDetectors[i].id + "NegLimitRow");
                    hide("pd" + pointDetectors[i].id + "WeightRow");
                    $set("pd" + pointDetectors[i].id + "Duration",pointDetectors[i].duration);
                    $set("pd" + pointDetectors[i].id + "DurationType",pointDetectors[i].durationType);
                }else if(pointDetectors[i].detectorType == <c:out value="<%= PointEventDetectorVO.TYPE_ALPHANUMERIC_STATE %>"/>){
                    if(pointDetectors[i].eventDescription.length==0)
                        $set("pd" + pointDetectors[i].id + "EventDescription","<fmt:message key="pointEdit.detectors.stateDet"/>");
                    hide("pd" + pointDetectors[i].id + "HighLimitRow");
                    hide("pd" + pointDetectors[i].id + "LowLimitRow");
                    hide("pd" + pointDetectors[i].id + "ChangeCountRow");
                    hide("pd" + pointDetectors[i].id + "PosLimitRow");
                    hide("pd" + pointDetectors[i].id + "NegLimitRow");
                    hide("pd" + pointDetectors[i].id + "WeightRow");
                    $set("pd" + pointDetectors[i].id + "Duration",pointDetectors[i].duration);
                    $set("pd" + pointDetectors[i].id + "DurationType",pointDetectors[i].durationType);
                }else if(pointDetectors[i].detectorType == <c:out value="<%= PointEventDetectorVO.TYPE_POSITIVE_CUSUM %>"/>){
                    if(pointDetectors[i].eventDescription.length==0)
                        $set("pd" + pointDetectors[i].id + "EventDescription","<fmt:message key="pointEdit.detectors.posCusumDet"/>");
                    hide("pd" + pointDetectors[i].id + "HighLimitRow");
                    hide("pd" + pointDetectors[i].id + "LowLimitRow");
                    hide("pd" + pointDetectors[i].id + "ChangeCountRow");
                    $set("pd" + pointDetectors[i].id + "PosLimit",pointDetectors[i].limit);
                    hide("pd" + pointDetectors[i].id + "NegLimitRow");
                    $set("pd" + pointDetectors[i].id + "Weight",pointDetectors[i].weight);
                    $set("pd" + pointDetectors[i].id + "Duration",pointDetectors[i].duration);
                    $set("pd" + pointDetectors[i].id + "DurationType",pointDetectors[i].durationType);
                }else if(pointDetectors[i].detectorType == <c:out value="<%= PointEventDetectorVO.TYPE_NEGATIVE_CUSUM %>"/>){
                    if(pointDetectors[i].eventDescription.length==0)
                        $set("pd" + pointDetectors[i].id + "EventDescription","<fmt:message key="pointEdit.detectors.negCusumDet"/>");
                    hide("pd" + pointDetectors[i].id + "HighLimitRow");
                    hide("pd" + pointDetectors[i].id + "LowLimitRow");
                    hide("pd" + pointDetectors[i].id + "ChangeCountRow");
                    hide("pd" + pointDetectors[i].id + "PosLimitRow");
                    $set("pd" + pointDetectors[i].id + "NegLimit",pointDetectors[i].limit);
                    $set("pd" + pointDetectors[i].id + "Weight",pointDetectors[i].weight);
                    $set("pd" + pointDetectors[i].id + "Duration",pointDetectors[i].duration);
                    $set("pd" + pointDetectors[i].id + "DurationType",pointDetectors[i].durationType);
                }
            }
            callback();
            pointDetectorsDialog.set("title", pointDetectors[0].dataPointExtendedName);
            pointDetectorsDialog.show();
        });
    }

    function updateAlarmLevelImage(alarmLevel, pedId) {
        setAlarmLevelImg(alarmLevel, byId("pd"+ pedId +"AlarmLevelImg"));
    }

    function getPedId(node) {
        while (!(node.pedId))
            node = node.parentNode;
        return node.pedId;
    }

    function saveEventDetectors(){
        var edTableNodes = byId("EventDetectorsDialogRow").childNodes;
        var error = false;

        dwr.engine.beginBatch();
        for (var i=0; i<edTableNodes.length; i++){
            if (!edTableNodes[i].pedId)
                continue;

            var pedId = edTableNodes[i].pedId;
            var pedType = edTableNodes[i].pedType;
            var errorMessage = null;
            var alarmLevel = $get("pd" + pedId + "AlarmLevel");

            if (pedType == <c:out value="<%= PointEventDetectorVO.TYPE_ANALOG_HIGH_LIMIT %>"/>){
                var limit = parseFloat($get("pd" + pedId + "HighLimit"));
                var duration = parseInt($get("pd" + pedId + "Duration"));
                var durationType = parseInt($get("pd" + pedId + "DurationType"));

                if (isNaN(limit))
                    errorMessage = "<fmt:message key="pointEdit.detectors.errorParsingLimit"/>";
                else if (isNaN(duration))
                    errorMessage = "<fmt:message key="pointEdit.detectors.errorParsingDuration"/>";
                else if (duration < 0)
                    errorMessage = "<fmt:message key="pointEdit.detectors.invalidDuration"/>";
                else
                    MiscDwr.savePointDetector(pedId, limit, 2, 0, duration, durationType, alarmLevel);

            }else if(pedType == <c:out value="<%= PointEventDetectorVO.TYPE_ANALOG_LOW_LIMIT %>"/>){
                var limit = parseFloat($get("pd" + pedId + "LowLimit"));
                var duration = parseInt($get("pd" + pedId + "Duration"));
                var durationType = parseInt($get("pd" + pedId + "DurationType"));

                if (isNaN(limit))
                    errorMessage = "<fmt:message key="pointEdit.detectors.errorParsingLimit"/>";
                else if (isNaN(duration))
                    errorMessage = "<fmt:message key="pointEdit.detectors.errorParsingDuration"/>";
                else if (duration < 0)
                    errorMessage = "<fmt:message key="pointEdit.detectors.invalidDuration"/>";
                else
                    MiscDwr.savePointDetector(pedId, limit, 2, 0, duration, durationType, alarmLevel);

            }else if(pedType == <c:out value="<%= PointEventDetectorVO.TYPE_BINARY_STATE %>"/>){
                var duration = parseInt($get("pd" + pedId + "Duration"));
                var durationType = parseInt($get("pd" + pedId + "DurationType"));

                if (isNaN(duration))
                    errorMessage = "<fmt:message key="pointEdit.detectors.errorParsingDuration"/>";
                else if (duration < 0)
                    errorMessage = "<fmt:message key="pointEdit.detectors.invalidDuration"/>";
                else
                    MiscDwr.savePointDetector(pedId, 0, 2, 0, duration, durationType, alarmLevel);

            }else if(pedType == <c:out value="<%= PointEventDetectorVO.TYPE_MULTISTATE_STATE %>"/>){
                var duration = parseInt($get("pd" + pedId + "Duration"));
                var durationType = parseInt($get("pd" + pedId + "DurationType"));

                if (isNaN(duration))
                    errorMessage = "<fmt:message key="pointEdit.detectors.errorParsingDuration"/>";
                else if (duration < 0)
                    errorMessage = "<fmt:message key="pointEdit.detectors.invalidDuration"/>";
                else
                    MiscDwr.savePointDetector(pedId, 0, 2, 0, duration, durationType, alarmLevel);

            }else if(pedType == <c:out value="<%= PointEventDetectorVO.TYPE_POINT_CHANGE %>"/>){

                MiscDwr.savePointDetector(pedId, 0, 2, 0, 0, 0, alarmLevel);

            }else if(pedType == <c:out value="<%= PointEventDetectorVO.TYPE_STATE_CHANGE_COUNT %>"/>){
                var count = parseInt($get("pd" + pedId + "ChangeCount"));
                var duration = parseInt($get("pd" + pedId + "Duration"));
                var durationType = parseInt($get("pd" + pedId + "DurationType"));

                if (isNaN(count))
                    errorMessage = "<fmt:message key="pointEdit.detectors.errorParsingChangeCount"/>";
                else if (count < 2)
                    errorMessage = "<fmt:message key="pointEdit.detectors.invalidChangeCount"/>";
                else if (isNaN(duration))
                    errorMessage = "<fmt:message key="pointEdit.detectors.errorParsingDuration"/>";
                else if (duration < 0)
                    errorMessage = "<fmt:message key="pointEdit.detectors.invalidDuration"/>";
                else
                    MiscDwr.savePointDetector(pedId, 0, changeCount, 0, duration, durationType, alarmLevel);

            }else if(pedType == <c:out value="<%= PointEventDetectorVO.TYPE_NO_CHANGE %>"/>){
                var duration = parseInt($get("pd" + pedId + "Duration"));
                var durationType = parseInt($get("pd" + pedId + "DurationType"));

                if (isNaN(duration))
                    errorMessage = "<fmt:message key="pointEdit.detectors.errorParsingDuration"/>";
                else if (duration < 0)
                    errorMessage = "<fmt:message key="pointEdit.detectors.invalidDuration"/>";
                else
                    MiscDwr.savePointDetector(pedId, 0, 2, 0, duration, durationType, alarmLevel);

            }else if(pedType == <c:out value="<%= PointEventDetectorVO.TYPE_NO_UPDATE %>"/>){
                var duration = parseInt($get("pd" + pedId + "Duration"));
                var durationType = parseInt($get("pd" + pedId + "DurationType"));

                if (isNaN(duration))
                    errorMessage = "<fmt:message key="pointEdit.detectors.errorParsingDuration"/>";
                else if (duration < 0)
                    errorMessage = "<fmt:message key="pointEdit.detectors.invalidDuration"/>";
                else
                    MiscDwr.savePointDetector(pedId, 0, 2, 0, duration, durationType, alarmLevel);

            }else if(pedType == <c:out value="<%= PointEventDetectorVO.TYPE_ALPHANUMERIC_STATE %>"/>){
                var duration = parseInt($get("pd" + pedId + "Duration"));
                var durationType = parseInt($get("pd" + pedId + "DurationType"));

                if (isNaN(duration))
                    errorMessage = "<fmt:message key="pointEdit.detectors.errorParsingDuration"/>";
                else if (duration < 0)
                    errorMessage = "<fmt:message key="pointEdit.detectors.invalidDuration"/>";
                else
                    MiscDwr.savePointDetector(pedId, 0, 2, 0, duration, durationType, alarmLevel);

            }else if(pedType == <c:out value="<%= PointEventDetectorVO.TYPE_POSITIVE_CUSUM %>"/>){
                var limit = parseFloat($get("pd" + pedId + "PosLimit"));
                var weight = parseFloat($get("pd" + pedId + "Weight"));
                var duration = parseInt($get("pd" + pedId + "Duration"));
                var durationType = parseInt($get("pd" + pedId + "DurationType"));

                if (isNaN(limit))
                    errorMessage = "<fmt:message key="pointEdit.detectors.errorParsingLimit"/>";
                else if (isNaN(weight))
                    errorMessage = "<fmt:message key="pointEdit.detectors.errorParsingWeight"/>";
                else if (count < 2)
                    errorMessage = "<fmt:message key="pointEdit.detectors.invalidChangeCount"/>";
                else if (isNaN(duration))
                    errorMessage = "<fmt:message key="pointEdit.detectors.errorParsingDuration"/>";
                else if (duration < 0)
                    errorMessage = "<fmt:message key="pointEdit.detectors.invalidDuration"/>";
                else
                    MiscDwr.savePointDetector(pedId, limit, 2, weight , duration, durationType, alarmLevel);

            }else if(pedType == <c:out value="<%= PointEventDetectorVO.TYPE_NEGATIVE_CUSUM %>"/>){
                var limit = parseFloat($get("pd" + pedId + "NegLimit"));
                var weight = parseFloat($get("pd" + pedId + "Weight"));
                var duration = parseInt($get("pd" + pedId + "Duration"));
                var durationType = parseInt($get("pd" + pedId + "DurationType"));

                if (isNaN(limit))
                    errorMessage = "<fmt:message key="pointEdit.detectors.errorParsingLimit"/>";
                else if (isNaN(weight))
                    errorMessage = "<fmt:message key="pointEdit.detectors.errorParsingWeight"/>";
                else if (count < 2)
                    errorMessage = "<fmt:message key="pointEdit.detectors.invalidChangeCount"/>";
                else if (isNaN(duration))
                    errorMessage = "<fmt:message key="pointEdit.detectors.errorParsingDuration"/>";
                else if (duration < 0)
                    errorMessage = "<fmt:message key="pointEdit.detectors.invalidDuration"/>";
                else
                    MiscDwr.savePointDetector(pedId, limit, 2, weight , duration, durationType, alarmLevel);
            }

            if (errorMessage != null){
                byId("pd"+ pedId +"ErrorMessage").innerHTML = errorMessage;
                error=true;
            }else
                byId("pd"+ pedId +"ErrorMessage").innerHTML = "";
        }
        dwr.engine.endBatch();
        if(!error)
            pointDetectorsDialog.hide();
    }
</script>
