--
--    Mango - Open Source M2M - http://mango.serotoninsoftware.com
--    Copyright (C) 2006-2011 Serotonin Software Technologies Inc.
--    @author Matthew Lohbihler
--
--    This program is free software: you can redistribute it and/or modify
--    it under the terms of the GNU General Public License as published by
--    the Free Software Foundation, either version 3 of the License, or
--    (at your option) any later version.
--
--    This program is distributed in the hope that it will be useful,
--    but WITHOUT ANY WARRANTY; without even the implied warranty of
--    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--    GNU General Public License for more details.
--
--    You should have received a copy of the GNU General Public License
--    along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
--

-- Make sure that everything get created with utf8 as the charset.
alter database default character set utf8;

--
-- System settings
create table systemSettings (
  settingName varchar(32) not null,
  settingValue longtext,
  primary key (settingName)
) engine=InnoDB;


--
-- Users
create table users (
  id int not null auto_increment,
  username varchar(40) not null,
  password varchar(128) not null,
  admin char(1) not null,
  disabled char(1) not null,
  lastLogin bigint,
  selectedWatchList int,
  homeUrl varchar(255),
  receiveAlarmEmails int not null,
  receiveOwnAuditEvents char(1) not null,
  receiveAlarmSms int not null,
  salt varchar(32) not null,
  lockStatus int not null,
  wrongPasswords int not null,
  unlockTime bigint,
  primary key (id)
) engine=InnoDB;

create table userComments (
  userId int,
  commentType int not null,
  typeKey int not null,
  ts bigint not null,
  commentText varchar(1024) not null
) engine=InnoDB;
alter table userComments add constraint userCommentsFk1 foreign key (userId) references users(id);

create table userDetails (
  userId int,
  typeId int not null,
  name varchar(128) not null,
  content varchar(128) not null,
  active char(1) not null
) engine=InnoDB;
alter table userDetails add constraint userDetailsFk1 foreign key (userId) references users(id);


--
-- Mailing lists
create table mailingLists (
  id int not null auto_increment,
  xid varchar(50) not null,
  name varchar(40) not null,
  primary key (id)
) engine=InnoDB;
alter table mailingLists add constraint mailingListsUn1 unique (xid);

create table mailingListInactive (
  mailingListId int not null,
  inactiveInterval int not null
) engine=InnoDB;
alter table mailingListInactive add constraint mailingListInactiveFk1 foreign key (mailingListId)
  references mailingLists(id) on delete cascade;

create table mailingListMembers (
  mailingListId int not null,
  typeId int not null,
  userId int,
  address varchar(255)
) engine=InnoDB;
alter table mailingListMembers add constraint mailingListMembersFk1 foreign key (mailingListId)
  references mailingLists(id) on delete cascade;

--
-- Phones lists
create table phonesLists (
  id int not null auto_increment,
  xid varchar(50) not null,
  name varchar(40) not null,
  primary key (id)
) engine=InnoDB;
alter table phonesLists add constraint phonesListsUn1 unique (xid);

create table phonesListInactive (
  phonesListId int not null,
  inactiveInterval int not null
) engine=InnoDB;
alter table phonesListInactive add constraint phonesListInactiveFk1 foreign key (phonesListId)
  references phonesLists(id) on delete cascade;

create table phonesListMembers (
  phonesListId int not null,
  typeId int not null,
  userId int,
  phone varchar(40)
) engine=InnoDB;
alter table phonesListMembers add constraint phonesListMembersFk1 foreign key (phonesListId)
  references phonesLists(id) on delete cascade;


--
--
-- Data Sources
--
create table dataSources (
  id int not null auto_increment,
  xid varchar(50) not null,
  name varchar(40) not null,
  dataSourceType int not null,
  data longblob not null,
  rtdata longblob,
  primary key (id)
) engine=InnoDB;
alter table dataSources add constraint dataSourcesUn1 unique (xid);


-- Data source permissions
create table dataSourceUsers (
  dataSourceId int not null,
  userId int not null
) engine=InnoDB;
alter table dataSourceUsers add constraint dataSourceUsersFk1 foreign key (dataSourceId) references dataSources(id);
alter table dataSourceUsers add constraint dataSourceUsersFk2 foreign key (userId) references users(id) on delete cascade;



--
--
-- Data Points
--
create table dataPoints (
  id int not null auto_increment,
  xid varchar(50) not null,
  dataSourceId int not null,
  data longblob not null,
  primary key (id)
) engine=InnoDB;
alter table dataPoints add constraint dataPointsUn1 unique (xid);
alter table dataPoints add constraint dataPointsFk1 foreign key (dataSourceId) references dataSources(id);


-- Data point permissions
create table dataPointUsers (
  dataPointId int not null,
  userId int not null,
  permission int not null
) engine=InnoDB;
alter table dataPointUsers add constraint dataPointUsersFk1 foreign key (dataPointId) references dataPoints(id);
alter table dataPointUsers add constraint dataPointUsersFk2 foreign key (userId) references users(id) on delete cascade;


--
--
-- Views
--
create table mangoViews (
  id int not null auto_increment,
  xid varchar(50) not null,
  name varchar(100) not null,
  background varchar(255),
  userId int not null,
  anonymousAccess int not null,
  data longblob not null,
  primary key (id)
) engine=InnoDB;
alter table mangoViews add constraint mangoViewsUn1 unique (xid);
alter table mangoViews add constraint mangoViewsFk1 foreign key (userId) references users(id) on delete cascade;

create table mangoViewUsers (
  mangoViewId int not null,
  userId int not null,
  accessType int not null,
  primary key (mangoViewId, userId)
) engine=InnoDB;
alter table mangoViewUsers add constraint mangoViewUsersFk1 foreign key (mangoViewId) references mangoViews(id);
alter table mangoViewUsers add constraint mangoViewUsersFk2 foreign key (userId) references users(id) on delete cascade;


--
--
-- Point Values (historical data)
--
create table pointValues (
  id bigint not null auto_increment,
  dataPointId int not null,
  dataType int not null,
  pointValue double,
  ts bigint not null,
  primary key (id)
) engine=InnoDB;
alter table pointValues add constraint pointValuesFk1 foreign key (dataPointId) references dataPoints(id) on delete cascade;
create index pointValuesIdx1 on pointValues (ts, dataPointId);
create index pointValuesIdx2 on pointValues (dataPointId, ts);

create table pointValueAnnotations (
  pointValueId bigint not null,
  textPointValueShort varchar(128),
  textPointValueLong longtext,
  sourceType smallint,
  sourceId int
) engine=InnoDB;
alter table pointValueAnnotations add constraint pointValueAnnotationsFk1 foreign key (pointValueId)
  references pointValues(id) on delete cascade;


--
--
-- Watch list
--
create table watchLists (
  id int not null auto_increment,
  xid varchar(50) not null,
  userId int not null,
  name varchar(50),
  primary key (id)
) engine=InnoDB;
alter table watchLists add constraint watchListsUn1 unique (xid);
alter table watchLists add constraint watchListsFk1 foreign key (userId) references users(id) on delete cascade;

create table watchListPoints (
  watchListId int not null,
  dataPointId int not null,
  sortOrder int not null
) engine=InnoDB;
alter table watchListPoints add constraint watchListPointsFk1 foreign key (watchListId) references watchLists(id) on delete cascade;
alter table watchListPoints add constraint watchListPointsFk2 foreign key (dataPointId) references dataPoints(id);

create table watchListUsers (
  watchListId int not null,
  userId int not null,
  accessType int not null,
  primary key (watchListId, userId)
) engine=InnoDB;
alter table watchListUsers add constraint watchListUsersFk1 foreign key (watchListId) references watchLists(id);
alter table watchListUsers add constraint watchListUsersFk2 foreign key (userId) references users(id) on delete cascade;


--
--
-- Point event detectors
--
create table pointEventDetectors (
  id int not null auto_increment,
  xid varchar(50) not null,
  alias varchar(255),
  dataPointId int not null,
  detectorType int not null,
  alarmLevel int not null,
  stateLimit double,
  duration int,
  durationType int,
  binaryState char(1),
  multistateState int,
  changeCount int,
  alphanumericState varchar(128),
  weight double,
  editPermission int not null,
  eventDescription varchar(255),
  primary key (id)
) engine=InnoDB;
alter table pointEventDetectors add constraint pointEventDetectorsUn1 unique (xid, dataPointId);
alter table pointEventDetectors add constraint pointEventDetectorsFk1 foreign key (dataPointId)
  references dataPoints(id);


--
--
-- Events
--
create table events (
  id int not null auto_increment,
  typeId int not null,
  typeRef1 int not null,
  typeRef2 int not null,
  activeTs bigint not null,
  rtnApplicable char(1) not null,
  rtnTs bigint,
  rtnCause int,
  alarmLevel int not null,
  message longtext,
  ackTs bigint,
  ackUserId int,
  alternateAckSource int,
  primary key (id)
) engine=InnoDB;
alter table events add constraint eventsFk1 foreign key (ackUserId) references users(id);

create table userEvents (
  eventId int not null,
  userId int not null,
  silenced char(1) not null,
  primary key (eventId, userId)
) engine=InnoDB;
alter table userEvents add constraint userEventsFk1 foreign key (eventId) references events(id) on delete cascade;
alter table userEvents add constraint userEventsFk2 foreign key (userId) references users(id);


--
--
-- Event handlers
--
create table eventHandlers (
  id int not null auto_increment,
  xid varchar(50) not null,
  alias varchar(255),

  -- Event type, see events
  eventTypeId int not null,
  eventTypeRef1 int not null,
  eventTypeRef2 int not null,

  data longblob not null,
  primary key (id)
) engine=InnoDB;
alter table eventHandlers add constraint eventHandlersUn1 unique (xid);


--
--
-- Scheduled events
--
create table scheduledEvents (
  id int not null auto_increment,
  xid varchar(50) not null,
  alias varchar(255),
  alarmLevel int not null,
  scheduleType int not null,
  returnToNormal char(1) not null,
  disabled char(1) not null,
  activeYear int,
  activeMonth int,
  activeDay int,
  activeHour int,
  activeMinute int,
  activeSecond int,
  activeCron varchar(25),
  inactiveYear int,
  inactiveMonth int,
  inactiveDay int,
  inactiveHour int,
  inactiveMinute int,
  inactiveSecond int,
  inactiveCron varchar(25),
  primary key (id)
) engine=InnoDB;
alter table scheduledEvents add constraint scheduledEventsUn1 unique (xid);


--
--
-- Point Hierarchy
--
create table pointHierarchy (
  id int not null auto_increment,
  parentId int,
  name varchar(100),
  primary key (id)
) engine=InnoDB;


--
--
-- Compound events detectors
--
create table compoundEventDetectors (
  id int not null auto_increment,
  xid varchar(50) not null,
  name varchar(100),
  alarmLevel int not null,
  returnToNormal char(1) not null,
  disabled char(1) not null,
  conditionText varchar(256) not null,
  primary key (id)
) engine=InnoDB;
alter table compoundEventDetectors add constraint compoundEventDetectorsUn1 unique (xid);


--
--
-- Reports
--
create table reports (
  id int not null auto_increment,
  userId int not null,
  name varchar(100) not null,
  data longblob not null,
  primary key (id)
) engine=InnoDB;
alter table reports add constraint reportsFk1 foreign key (userId) references users(id) on delete cascade;

create table reportInstances (
  id int not null auto_increment,
  userId int not null,
  name varchar(100) not null,
  includeEvents int not null,
  includeUserComments char(1) not null,
  reportStartTime bigint not null,
  reportEndTime bigint not null,
  runStartTime bigint,
  runEndTime bigint,
  recordCount int,
  preventPurge char(1),
  primary key (id)
) engine=InnoDB;
alter table reportInstances add constraint reportInstancesFk1 foreign key (userId) references users(id) on delete cascade;

create table reportInstancePoints (
  id int not null auto_increment,
  reportInstanceId int not null,
  dataSourceName varchar(40) not null,
  pointName varchar(100) not null,
  dataType int not null,
  startValue varchar(4096),
  textRenderer longblob,
  colour varchar(6),
  consolidatedChart char(1),
  primary key (id)
) engine=InnoDB;
alter table reportInstancePoints add constraint reportInstancePointsFk1 foreign key (reportInstanceId)
  references reportInstances(id) on delete cascade;

create table reportInstanceData (
  pointValueId bigint not null,
  reportInstancePointId int not null,
  pointValue double,
  ts bigint not null,
  primary key (pointValueId, reportInstancePointId)
) engine=InnoDB;
alter table reportInstanceData add constraint reportInstanceDataFk1 foreign key (reportInstancePointId)
  references reportInstancePoints(id) on delete cascade;

create table reportInstanceDataAnnotations (
  pointValueId bigint not null,
  reportInstancePointId int not null,
  textPointValueShort varchar(128),
  textPointValueLong longtext,
  sourceValue varchar(128),
  primary key (pointValueId, reportInstancePointId)
) engine=InnoDB;
alter table reportInstanceDataAnnotations add constraint reportInstanceDataAnnotationsFk1
  foreign key (pointValueId, reportInstancePointId) references reportInstanceData(pointValueId, reportInstancePointId)
  on delete cascade;

create table reportInstanceEvents (
  eventId int not null,
  reportInstanceId int not null,
  typeId int not null,
  typeRef1 int not null,
  typeRef2 int not null,
  activeTs bigint not null,
  rtnApplicable char(1) not null,
  rtnTs bigint,
  rtnCause int,
  alarmLevel int not null,
  message longtext,
  ackTs bigint,
  ackUsername varchar(40),
  alternateAckSource int,
  primary key (eventId, reportInstanceId)
) engine=InnoDB;
alter table reportInstanceEvents add constraint reportInstanceEventsFk1 foreign key (reportInstanceId)
  references reportInstances(id) on delete cascade;

create table reportInstanceUserComments (
  reportInstanceId int not null,
  username varchar(40),
  commentType int not null,
  typeKey int not null,
  ts bigint not null,
  commentText varchar(1024) not null
) engine=InnoDB;
alter table reportInstanceUserComments add constraint reportInstanceUserCommentsFk1 foreign key (reportInstanceId)
  references reportInstances(id) on delete cascade;


--
--
-- Publishers
--
create table publishers (
  id int not null auto_increment,
  xid varchar(50) not null,
  data longblob not null,
  rtdata longblob,
  primary key (id)
) engine=InnoDB;
alter table publishers add constraint publishersUn1 unique (xid);


--
--
-- Point links
--
create table pointLinks (
  id int not null auto_increment,
  xid varchar(50) not null,
  sourcePointId int not null,
  targetPointId int not null,
  script longtext,
  eventType int not null,
  disabled char(1) not null,
  updateType int not null,
  primary key (id)
) engine=InnoDB;
alter table pointLinks add constraint pointLinksUn1 unique (xid);


--
--
-- Maintenance events
--
create table maintenanceEvents (
  id int not null auto_increment,
  xid varchar(50) not null,
  dataSourceId int not null,
  alias varchar(255),
  alarmLevel int not null,
  scheduleType int not null,
  disabled char(1) not null,
  activeYear int,
  activeMonth int,
  activeDay int,
  activeHour int,
  activeMinute int,
  activeSecond int,
  activeCron varchar(25),
  inactiveYear int,
  inactiveMonth int,
  inactiveDay int,
  inactiveHour int,
  inactiveMinute int,
  inactiveSecond int,
  inactiveCron varchar(25),
  primary key (id)
) engine=InnoDB;
alter table maintenanceEvents add constraint maintenanceEventsUn1 unique (xid);
alter table maintenanceEvents add constraint maintenanceEventsFk1 foreign key (dataSourceId) references dataSources(id);


--
--
-- Texting
--
create table textGateways (
  id int not null auto_increment,
  xid varchar(50) not null,
  name varchar(100) not null,
  sortOrder int not null,
  data longblob not null,
  primary key (id)
) engine=InnoDB;
alter table textGateways add constraint textGatewaysUn1 unique (xid);

create table textMessages (
  id int not null auto_increment,
  dateTime bigint not null,
  type int not null,
  textGateway int not null,
  recipient varchar(13) not null,
  content varchar(120) not null,
  status int not null,
  returnDateTime bigint,
  preventPurge char(1) not null,
  smsRef int not null,
  primary key (id)
) engine=InnoDB;
