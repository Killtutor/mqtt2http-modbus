<#--
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
-->
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">

<html>
<head>
  <title><@fmt key="header.title"/></title>

  <!-- Meta -->
  <meta http-equiv="content-type" content="application/xhtml+xml;charset=utf-8"/>
  <meta http-equiv="Content-Style-Type" content="text/css" />
  <meta name="Copyright" content="&copy;2014 Vemetris"/>

  <!-- Style -->
  <link rel="icon" href="images/favicon_01.ico"/>
  <link rel="shortcut icon" href="images/favicon_01.ico"/>
</head>

<body>
<div style="background-color: #E1E6E6; min-width: 930px; margin-left: auto; margin-right: auto; padding: 0px; padding-top:10px; border: 1px solid black;
        padding-bottom:10px; font-family: Verdana, Arial, Helvetica, sans-serif; font-size: 11px;">

  <div style=" width:100%; margin:5px; padding:0px; text-align:center;"><img src="${inline}<@img src="instanceLogo.png"/>" alt="Logo"/></td></div>

  <div style="font-family: Verdana, Arial, Helvetica, sans-serif; font-size: 20px; font-weight: bold; width:100%; text-align:center;padding:5px;color: black;">
    ${instanceName} - <@fmt key="reports.report"/>
  </div>

  <div align="center">
  <table style="font-family: Verdana, Arial, Helvetica, sans-serif; margin-bottom:30px; border: 1px solid black; background-color:white;">
    <tr>
      <td style="font-weight: bold; text-align: right; padding-right: 10px;"><@fmt key="reports.report"/>:</td>
      <td style="min-width:50%;">${instance.name}</td>
    </tr>
    <tr>
      <td style="font-weight: bold; text-align: right; padding-right: 10px;"><@fmt key="reports.runTimeStart"/></td>
      <td style="min-width:50%;">${instance.prettyRunStartTime}</td>
    </tr>
    <tr>
      <td style="font-weight: bold; text-align: right; padding-right: 10px;"><@fmt key="reports.runDuration"/></td>
      <td style="min-width:50%;">${instance.prettyRunDuration}</td>
    </tr>
    <tr>
      <td style="font-weight: bold; text-align: right; padding-right: 10px;"><@fmt key="reports.dateRange"/></td>
      <td style="min-width:50%;">${instance.prettyReportStartTime} <@fmt key="reports.dateRangeTo"/> ${instance.prettyReportEndTime}</td>
    </tr>
  </table>
  </div>

  <div style="font-family: Verdana, Arial, Helvetica, sans-serif; font-size: 18px; font-weight: bold; width:100%; text-align:center;padding:5px;color: black;">
    <@fmt key="reports.statistics"/>
  </div>
  <table width="100%">
    <#assign col = 1/>
    <#list points as point>
      <#assign col = col + 1/>
      <#if col == 2><#assign col = 0/></#if>
      <#if col == 0><tr></#if>

      <td style="background-color: transparent; vertical-align: top; text-align:center; width:50%;">
        <table width="100%" style="width:100%;color: black;">
          <tr><td colspan="2" style="color: #125987; font-size: 13px; font-weight: bold;">${point.name}</td></tr>
          <tr>
            <td style="font-weight: bold; text-align: right; padding-right: 10px; width:40%;"><@fmt key="reports.dataType"/></td>
            <td style="text-align:left;width:60%;">${point.dataTypeDescription}</td>
          </tr>
          <#if point.startValue??>
            <tr>
              <td style="font-weight: bold; text-align: right; padding-right: 10px; width:40%;"><@fmt key="common.stats.start"/></td>
              <td style="text-align:left;width:60%;">${point.startValue}</td>
            </tr>
          </#if>
          <#if point.dataType == NUMERIC>
            <tr>
              <td style="font-weight: bold; text-align: right; padding-right: 10px; width:40%;"><@fmt key="common.stats.min"/></td>
              <td style="text-align:left;width:60%;">${point.analogMinimum} @ ${point.analogMinTime}</td>
            </tr>
            <tr>
              <td style="font-weight: bold; text-align: right; padding-right: 10px; width:40%;"><@fmt key="common.stats.max"/></td>
              <td style="text-align:left;width:60%;">${point.analogMaximum} @ ${point.analogMaxTime}</td>
            </tr>
            <tr>
              <td style="font-weight: bold; text-align: right; padding-right: 10px; width:40%;"><@fmt key="common.stats.avg"/></td>
              <td style="text-align:left;width:60%;">${point.analogAverage}</td>
            </tr>
          <#elseif point.dataType == BINARY || point.dataType == MULTISTATE>
            <tr>
              <td colspan="2" align="center">
                <table style="border:1px solid #125987;">
                  <tr style="padding-top:15px">
                    <th><@fmt key="common.stats.value"/></th>
                    <th><@fmt key="common.stats.starts"/></th>
                    <th><@fmt key="common.stats.runtime"/></th>
                  </tr>

                  <#list point.startsAndRuntimes as sar>
                    <tr>
                      <td>${sar.value}</td>
                      <td align="right">${sar.starts}</td>
                      <td align="right">${sar.runtime}</td>
                    </tr>
                  </#list>
                </table>
              </td>
            </tr>
          <#elseif point.dataType == ALPHANUMERIC || point.dataType == IMAGE>
            <tr>
              <td style="font-weight: bold; text-align: right; padding-right: 10px; width:40%;"><@fmt key="common.stats.count"/></td>
              <td>${point.valueChangeCount}</td>
            </tr>
          </#if>
          <#if point.chartData>
            <tr>
              <td colspan="2"><img src="${inline}${point.chartPath}"/></td>
            </tr>
          </#if>
        </table>
      </td>

      <#if col == 1></tr></#if>
    </#list>
    <#if col < 1></tr></#if>
  </table>

  <#if chartName??>
    <div style="font-family: Verdana, Arial, Helvetica, sans-serif; font-size: 18px; font-weight: bold; width:100%; text-align:center;padding:5px;color: black;">
      <@fmt key="reports.consolidated"/>
    </div>
    <div style="width:100%;text-align:center;"><img src="${inline}${chartName}"/></div>
  </#if>

  <#if includeEvents>
  <div style="font-family: Verdana, Arial, Helvetica, sans-serif; font-size: 18px; font-weight: bold; width:100%; text-align:center;padding:5px;color: black;">
    <@fmt key="reports.events"/>
  </div>
    <#if events?size == 0>
      <div style="width:100%;text-align:center;"><@fmt key="events.emptyList"/></div>
    <#else>
      <table cellspacing="1" cellpadding="0" width="100%" style="color:black;">
        <tr style="font-weight: bold; color: #FFFFFF; background-color: #51A6CD; text-align: center; white-space: nowrap; padding: 3px 10px 3px 10px;">
          <td><@fmt key="reports.eventList.id"/></td>
          <td><@fmt key="common.alarmLevel"/></td>
          <td><@fmt key="common.activeTime"/></td>
          <td><@fmt key="reports.eventList.message"/></td>
          <td><@fmt key="reports.eventList.status"/></td>
          <td><@fmt key="events.acknowledged"/></td>
        </tr>

        <#assign row = 1/>
        <#list events as event>
          <#assign row = row + 1/>
          <#if row == 2><#assign row = 0/></#if>

          <tr>
            <td align="center">${event.id?c}</td>
            <td align="center">
              <#if event.alarmLevel == 0><img src="${inline}<@img src="flag_green.png"/>" alt="<@fmt key="common.alarmLevel.none"/>"/>
              <#elseif event.alarmLevel == 1><img src="${inline}<@img src="flag_blue.png"/>" alt="<@fmt key="common.alarmLevel.info"/>"/>
              <#elseif event.alarmLevel == 2><img src="${inline}<@img src="flag_yellow.png"/>" alt="<@fmt key="common.alarmLevel.urgent"/>"/>
              <#elseif event.alarmLevel == 3><img src="${inline}<@img src="flag_orange.png"/>" alt="<@fmt key="common.alarmLevel.critical"/>"/>
              <#elseif event.alarmLevel == 4><img src="${inline}<@img src="flag_red.png"/>" alt="<@fmt key="common.alarmLevel.lifeSafety"/>"/>
              <#else>(<@fmt key="common.alarmLevel.unknown"/>  ${event.alarmLevel})
              </#if>
            </td>
            <td>${event.fullPrettyActiveTimestamp}</td>
            <td>
              <b><@fmt message=event.message/></b>
              <#if event.eventComments??>
                <table cellspacing="0" cellpadding="0">
                  <#list event.eventComments as comment>
                    <tr>
                      <td valign="top" width="16"><img src="${inline}<@img src="comment.png"/>" alt="<@fmt key="notes.note"/>"/></td>
                      <td valign="top">
                        <span style="color: #125987; font-size: 10px;">
                          ${comment.prettyTime} <@fmt key="notes.by"/>
                          <#if comment.username??>
                            ${comment.username}
                          <#else>
                            <@fmt key="common.deleted"/>
                          </#if>
                        </span><br/>
                        ${comment.comment}
                      </td>
                    </tr>
                  </#list>
                </table>
              </#if>
            </td>
            <td>
              <#if event.active>
                <@fmt key="common.active"/>
                <img src="${inline}<@img src="flag_white.png"/>" alt="<@fmt key="common.active"/>"/>
              <#elseif !event.rtnApplicable>
              <#else>
                ${event.fullPrettyRtnTimestamp} - <@fmt message=event.rtnMessage/>
              </#if>
            </td>
            <td>
              <#if event.acknowledged>
                ${event.fullPrettyAcknowledgedTimestamp}
                <@fmt message=event.ackMessage/>
              </#if>
            </td>
          </tr>
        </#list>
      </table>
    </#if>
  </#if>

  <#if includeUserComments>
  <div style="font-family: Verdana, Arial, Helvetica, sans-serif; font-size: 18px; font-weight: bold; width:100%; text-align:center;padding:5px;color: black;">
    <@fmt key="reports.pointComments"/>
  </div>
    <#if userComments?size == 0>
      <div style="width:100%;text-align:center;color:black;"><@fmt key="reports.pointComments.empty"/></div>
    <#else>
      <table cellspacing="0" cellpadding="0" style="color: black;">
        <#list userComments as comment>
          <tr>
            <td valign="top" width="16"><img src="${inline}<@img src="comment.png"/>" alt="<@fmt key="notes.note"/>"/></td>
            <td valign="top">
              <span style="color: #125987; font-size: 10px;">
                ${comment.prettyTime} <@fmt key="notes.by"/>
                <#if comment.username??>
                  ${comment.username},
                <#else>
                  <@fmt key="common.deleted"/>,
                </#if>
                '${comment.pointName}'
              </span><br/>
              ${comment.comment}
            </td>
          </tr>
        </#list>
      </table>
    </#if>
  </#if>
</div>

<div style="font-family: Verdana, Arial, Helvetica, sans-serif; color: #333333; font-size: 9px; width:100%; margin-bottom:10px; clear:left;">
  <div style="margin:0px auto;text-align:center;color: black;">Copyright &copy; 2014 Vemetris, reservados todos los derechos</div>
  <div style="margin:0px auto;text-align:center;color: black;"><a href="http://www.vemetris.com/">www.vemetris.com</a></div>
</div>

</body>
</html>