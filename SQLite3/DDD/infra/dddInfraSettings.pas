/// shared DDD Infrastructure: Application/Daemon settings classes
// - this unit is a part of the freeware Synopse mORMot framework,
// licensed under a MPL/GPL/LGPL tri-license; version 1.18
unit dddInfraSettings;

{
    This file is part of Synopse mORMot framework.

    Synopse mORMot framework. Copyright (C) 2015 Arnaud Bouchez
      Synopse Informatique - http://synopse.info

  *** BEGIN LICENSE BLOCK *****
  Version: MPL 1.1/GPL 2.0/LGPL 2.1

  The contents of this file are subject to the Mozilla Public License Version
  1.1 (the "License"); you may not use this file except in compliance with
  the License. You may obtain a copy of the License at
  http://www.mozilla.org/MPL

  Software distributed under the License is distributed on an "AS IS" basis,
  WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
  for the specific language governing rights and limitations under the License.

  The Original Code is Synopse mORMot framework.

  The Initial Developer of the Original Code is Arnaud Bouchez.

  Portions created by the Initial Developer are Copyright (C) 2015
  the Initial Developer. All Rights Reserved.

  Contributor(s):


  Alternatively, the contents of this file may be used under the terms of
  either the GNU General Public License Version 2 or later (the "GPL"), or
  the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
  in which case the provisions of the GPL or the LGPL are applicable instead
  of those above. If you wish to allow use of your version of this file only
  under the terms of either the GPL or the LGPL, and not to allow others to
  use your version of this file under the terms of the MPL, indicate your
  decision by deleting the provisions above and replace them with the notice
  and other provisions required by the GPL or the LGPL. If you do not delete
  the provisions above, a recipient may use your version of this file under
  the terms of any one of the MPL, the GPL or the LGPL.

  ***** END LICENSE BLOCK *****

  Version 1.18
  - first public release, corresponding to Synopse mORMot Framework 1.18

  TODO:
   - store settings in database
   - allow to handle authentication via a centralized service or REST server

}

{$I Synopse.inc} // define HASINLINE USETYPEINFO CPU32 CPU64 OWNNORMTOUPPER

interface

uses
  SysUtils,
  Classes,
  SynCommons,
  SynLog,
  mORMot,
  mORMotDDD,
  SynSQLite3, mORMotSQLite3, // for internal SQlite3 database
  SynDB, mORMotDB,  // for TDDDRestSettings on external SQL database
  mORMotMongoDB,    // for TDDDRestSettings on external NoSQL database
  mORMotWrappers;   // for TDDDRestSettings to publish wrapper methods


{ ----- Manage Service/Daemon settings }

type
  /// abstract class for storing application settings
  // - this class implements IAutoCreateFieldsResolve so is able to inject
  // its own values to any TInjectableAutoCreateFields instance
  // - you have to manage instance lifetime of these inherited classes with a
  // local IAutoCreateFieldsResolve variable, just like any TInterfaceObject
  TDDDAppSettingsAbstract = class(TInterfacedObjectAutoCreateFields,
    IAutoCreateFieldsResolve)
  protected
    fAllProps: PPropInfoDynArray;
    fInitialJsonContent: RawUTF8;
    procedure SetProperties(Instance: TObject); virtual;
    // inherited constructors should use this method to initialize the content
    procedure SetJsonContent(JsonContent: PUTF8Char); virtual;
  public
    /// returns TRUE if the content did change according to its initial state
    // - will be used e.g. to update the file content on disk only if worth it
    function WasModified: Boolean;
    /// the JSON content, as specified when creating the instance
    // - will allow SettingsDidChange to check if has changed
    // - here the JSON content is stored with default ObjectToJSON() options,
    // so will be the normalized representation of the content, which may not
    // match the JSON supplied to SetJsonContent() protected method
    property InitialJsonContent: RawUTF8 read fInitialJsonContent;
  end;

  /// settings used to define how logging take place
  // - will map the most used TSynLogFamily parameters
  TDDDLogSettings = class(TSynPersistent)
  protected
    fLevels: TSynLogInfos;
    fConsoleLevels: TSynLogInfos;
    fAutoFlush: integer;
    fStackTraceViaAPI: boolean;
    fPerThread: TSynLogPerThreadMode;
    fDestinationPath: TFileName;
    fRotateFileCount: cardinal;
    fRotateFileSize: cardinal;
    fRotateFileAtHour: integer;
  public
    /// initialize the settings to their (TSynLogFamily) default values
    constructor Create; override;
  published
    /// the log levels to be used for the log file
    // - i.e. a combination of none or several logging event
    // - if "*" is serialized, unneeded sllNone won't be part of the set
    property Levels: TSynLogInfos read fLevels write fLevels;
    /// the optional log levels to be used for the console
    // - by default, only errors would be logged to the console
    // - you can specify here another set of levels, e.g. '*' for a verbose
    // console output - note that console is very slow to write, so usually
    // you should better not set a verbose definition here, unless you are
    // in debugging mode
    property ConsoleLevels: TSynLogInfos read fConsoleLevels write fConsoleLevels;
    /// the time (in seconds) after which the log content must be written on
    // disk, whatever the current content size is
    // - by default, the log file will be written for every 4 KB of log (see
    // TSynLogFamily.BufferSize property) - this will ensure that the main
    // application won't be slow down by logging
    // - in order not to loose any log, a background thread can be created
    // and will be responsible of flushing all pending log content every
    // period of time (e.g. every 10 seconds)
    // - this parameter is effective only under Linux by now
    property AutoFlushTimeOut: integer read fAutoFlush write fAutoFlush;
    /// the logged information about threads
    // - the default value is ptIdentifiedInOnFile, since it sounds more
    // reasonable to a multi-threaded server instance
    property PerThread: TSynLogPerThreadMode read fPerThread write fPerThread;
    /// by default (false), logging will use manual stack trace browsing
    // - if you experiment unexpected EAccessViolation, try to set this setting
    // to TRUE so that the RtlCaptureStackBackTrace() API would be used instead 
    property StackTraceViaAPI: boolean read FStackTraceViaAPI write FStackTraceViaAPI;
    /// allows to customize where the log files will be stored
    property DestinationPath: TFileName read FDestinationPath write FDestinationPath;
    /// auto-rotation of logging files
    // - set to 0 by default, meaning no rotation
    property RotateFileCount: cardinal read fRotateFileCount write fRotateFileCount;
    /// maximum size of auto-rotated logging files, in kilo-bytes (per 1024 bytes)
    property RotateFileSizeKB: cardinal read fRotateFileSize write fRotateFileSize;
    /// fixed hour of the day where logging files rotation should be performed
   property RotateFileDailyAtHour: integer read fRotateFileAtHour write fRotateFileAtHour;
  end;

  /// parent class for storing application settings as a JSON file
  TDDDAppSettingsFile = class(TDDDAppSettingsAbstract)
  protected
    fSettingsJsonFileName: TFileName;
    fDescription: string;
    fLog: TDDDLogSettings;
  public
    /// initialize and read the settings from the supplied JSON file name
    // - if no file name is specified, will use the executable name with
    // '.settings' as extension
    constructor Create(const aSettingsJsonFileName: TFileName=''); reintroduce; virtual;
    /// save to file and finalize the settings
    destructor Destroy; override;
    /// save settings to file
    // - any enumerated or set published property will be commented with their
    // textual values, and 'stored false' properties would be included
    procedure UpdateFile; virtual;
    /// to be called when the application starts, to access settings
    // - will change the system current directory to SettingsJsonFileName, and
    // set the log settings as expected
    // - you can specify a default Description value
    procedure Initialize(const aDescription: string); virtual;
    /// compute a file name relative to the .settings file path
    function FileNameRelativeToSettingsFile(const aFileName: TFileName): TFileName;
    /// the .settings file name, including full path
    property SettingsJsonFileName: TFileName
      read fSettingsJsonFileName write fSettingsJsonFileName;
  published
    /// some text which will be used to describe this application
    property Description: string read FDescription write FDescription;
    /// defines how logging will be done for this application
    property Log: TDDDLogSettings read fLog;
  end;

  /// some options to be used for TDDDRestSettings
  TDDDRestSettingsOption =
    (optEraseDBFileAtStartup,optStoreDBFileRelativeToSettings,
     optSQlite3FileSafeSlowMode);

  /// define options to be used for TDDDRestSettings
  TDDDRestSettingsOptions = set of TDDDRestSettingsOption;

  /// how TDDDRestSettings.NewRestInstance would create its instances
  // - riOwnModel will set ModelInstance.Owner := RestInstance
  // - riHandleAuthentication will set the corresponding parameter to true
  // - riDefaultLocalSQlite3IfNone will create a SQLite3 engine with a local
  // file, if TDDDRestSettings.ORM.Kind is not set
  // - TSQLRestServerFullMemory will create a TSQLRestServerFullMemory
  // storage, if TDDDRestSettings.ORM.Kind is not set
  // - riCreateMissingTables will call RestInstance.CreateMissingTables
  TDDDNewRestInstanceOptions = set of (
    riOwnModel,
    riHandleAuthentication,
    riDefaultLocalSQlite3IfNone, riDefaultInMemorySQLite3IfNone,
    riDefaultFullMemoryIfNone,
    riCreateMissingTables);

  /// storage class for initializing an ORM REST class
  // - this class will contain some generic properties to initialize a TSQLRest
  // pointing to a local or remote SQL/NoSQL database, with optional wrappers
  TDDDRestSettings = class(TSynAutoCreateFields)
  protected
    fORM: TSynConnectionDefinition;
    fRoot: RawUTF8;
    fWrapperTemplateFolder: TFileName;
    fWrapperSourceFolders: TFileName;
    fOptions: TDDDRestSettingsOptions;
    fWrapperTemplateFolderFixed: TFileName;
    fWrapperSourceFolderFixed: TFileName;
  public
    /// is able to instantiate a REST instance according to the stored definition
    // - Definition.Kind will identify the TSQLRestServer or TSQLRestClient class
    // to be instantiated, or if equals 'MongoDB' use a full MongoDB store, or an
    // external SQL database if it matches a TSQLDBConnectionProperties classname
    // - if aDefaultLocalSQlite3 is TRUE, then if Definition.Kind is '',
    // a local SQlite3 file database will be initiated
    // - will return nil if the supplied Definition is not correct
    // - note that the supplied Model.Root is expected to be the default root
    // URI, which will be overriden with this TDDDRestSettings.Root property
    // - will also set the TSQLRest.LogFamily.Level from LogLevels value,
    // and publish the /wrapper HTML page if WrapperTemplateFolder is set
    function NewRestInstance(aRootSettings: TDDDAppSettingsFile;
      aModel: TSQLModel; aOptions: TDDDNewRestInstanceOptions;
      aExternalDBOptions: TVirtualTableExternalRegisterOptions=[regDoNotRegisterUserGroupTables];
      aMongoDBOptions: TStaticMongoDBRegisterOptions=[mrDoNotRegisterUserGroupTables]): TSQLRest; virtual;
    /// returns the WrapperTemplateFolder property, all / chars replaced by \
    // - so that you would be able to store the paths with /, avoiding JSON escape
    function WrapperTemplateFolderFixed: TFileName;
    /// returns the WrapperSourceFolder property, all / chars replaced by \
    // - so that you would be able to store the paths with /, avoiding JSON escape
    function WrapperSourceFolderFixed: TFileName;
  published
    /// the URI Root to be used for the REST Model
    property Root: RawUTF8 read fRoot write fRoot;
    /// would let function NewRestInstance() create the expected TSQLRest
    property ORM: TSynConnectionDefinition read fORM;
    /// if set to a valid folder, the generated TSQLRest will publish a
    // '/Root/wrapper' HTML page so that client code could be generated
    property WrapperTemplateFolder: TFileName
      read fWrapperTemplateFolder write fWrapperTemplateFolder;
    /// where the source code may be searched, for comment extraction of types
    // - several folders may be defined, separated by ; (just like in Delphi IDE)
    // - only used if WrapperTemplateFolder is defined
    property WrapperSourceFolders: TFileName
      read fWrapperSourceFolders write fWrapperSourceFolders;
    /// how the REST instance is to be initialized
    property Options: TDDDRestSettingsOptions read fOptions write fOptions;
  end;

  /// parent class for storing REST-based application settings as a JSON file
  // - this class could be used for an application with a single REST server
  // running on a given HTTP port
  TDDDAppSettingsRestFile = class(TDDDAppSettingsFile)
  protected
    fRest: TDDDRestSettings;
    fServerPort: RawUTF8;
  public
    /// to be called when the application starts, to access settings
    // - will call inherited TDDDAppSettingsFile.Initialize, and
    // set ServerPort to a default 888/8888 value under Windows/Linux
    procedure Initialize(const aDescription: string); override;
  published
    /// allow to instantiate a REST instance from its JSON definition
    property Rest: TDDDRestSettings read fRest;
    /// the IP port to be used for the HTTP server associated with the application
    property ServerPort: RawUTF8 read fServerPort write fServerPort;
  end;

  /// define how an administrated service/daemon is remotely accessed via REST
  // - the IAdministratedDaemon service will be published to administrate
  // this service/daemon instance
  // - those values should match the ones used on administrative tool side
  TDDDAdministratedDaemonSettings = class(TSynAutoCreateFields)
  protected
    FAuthRootURI: RawUTF8;
    FAuthHashedPassword: RawUTF8;
    FAuthUserName: RawUTF8;
    FAuthNamedPipeName: TFileName;
    FAuthHttp: TSQLHttpServerDefinition;
  public
    /// set default settings
    // - i.e. AuthRootURI='admin' and plain AuthHttp.WebSocketPassword=ClassName
    constructor Create; override;
  published
    /// the root URI used for the REST data model
    // - default URI is 'admin'
    property AuthRootURI: RawUTF8 read FAuthRootURI write FAuthRootURI;
    /// if set, expect authentication with this single user name
    // - that is, the TSQLRestServer will register a single TSQLAuthUser
    // instance with the supplied AuthUserName/AuthHashedPassword credentials
    property AuthUserName: RawUTF8 read FAuthUserName write FAuthUserName;
    /// the SHA-256 hashed password to authenticate AuthUserName
    // - follows the TSQLAuthUser.PasswordHashHexa expectations
    // - marked as 'stored false' so that it won't appear e.g. in the logs
    property AuthHashedPassword: RawUTF8 read FAuthHashedPassword write FAuthHashedPassword
      stored false;
    /// if defined, the following pipe name would be used for REST publishing
    // - by definition, will work only on Windows
    property AuthNamedPipeName: TFileName read FAuthNamedPipeName write FAuthNamedPipeName;
    /// if defined, these parameters would be used for REST publishing over HTTP
    property AuthHttp: TSQLHttpServerDefinition read FAuthHttp;
  end;

  /// parent class for storing a service/daemon settings as a JSON file
  // - under Windows, some Service* properties will handle installaiton as a
  // regular Windows Service, thanks to TDDDDaemon
  TDDDAdministratedDaemonSettingsFile = class(TDDDAppSettingsFile)
  protected
    FRemoteAdmin: TDDDAdministratedDaemonSettings;
    FServiceDisplayName: string;
    FServiceName: string;
    FServiceAutoStart: boolean;
  public
    /// to be called when the application starts, to access settings
    // - you can specify default Description and Service identifiers
    procedure Initialize(
      const aDescription,aServiceName,aServiceDisplayName: string); reintroduce; virtual;
  published
    /// define how this administrated service/daemon is accessed via REST
    property RemoteAdmin: TDDDAdministratedDaemonSettings read FRemoteAdmin;
    /// under Windows, will define the Service internal name
    property ServiceName: string read FServiceName write FServiceName;
    /// under Windows, will define the Service displayed name
    property ServiceDisplayName: string read FServiceDisplayName write FServiceDisplayName;
    /// under Windows, will define if the Service should auto-start at boot
    // - FALSE means that it should be started on demand
    property ServiceAutoStart: boolean read FServiceAutoStart write FServiceAutoStart;
  end;

  /// the settings of a TDDDThreadSocketProcess thread
  // - defines how to connect (and reconnect) to the associated TCP server
  TDDDSocketThreadSettings = class(TPersistentAutoCreateFields)
  protected
    fHost: RawUTF8;
    fPort: integer;
    fSocketTimeout: integer;
    fConnectionAttemptsInterval: Integer;
    fAutoReconnectAfterSocketError: boolean;
    fMonitoringInterval: integer;
  public
    /// used to set the default values
    constructor Create; override;
  published
    /// the associated TCP server host
    property Host: RawUTF8 read FHost write FHost;
    /// the associated TCP server port
    property Port: integer read FPort write FPort;
    /// the time out period, in milliseconds, for socket access
    property SocketTimeout: integer read FSocketTimeout write FSocketTimeout;
    /// the time, in seconds, between any reconnection attempt
    // - default value is 5 - i.e. five seconds
    property ConnectionAttemptsInterval: Integer
      read fConnectionAttemptsInterval write fConnectionAttemptsInterval;
    /// if TRUE, any communication error would try to reconnect the socket
    property AutoReconnectAfterSocketError: boolean
      read FAutoReconnectAfterSocketError write FAutoReconnectAfterSocketError;
    /// the period, in milliseconds, on which Monitoring information is logged
    // - default value is 30000, i.e. 30 seconds
    property MonitoringLogInterval: integer read FMonitoringInterval write FMonitoringInterval;
  end;


implementation


{ TDDDAppSettingsAbstract }

procedure TDDDAppSettingsAbstract.SetJsonContent(
  JsonContent: PUTF8Char);
var valid: boolean;
begin
  if JsonContent=nil then
    exit;
  RemoveCommentsFromJSON(JsonContent);
  JSONToObject(self,JsonContent,valid);
  if valid then
    fInitialJsonContent := ObjectToJSON(self,[]);
end;

procedure TDDDAppSettingsAbstract.SetProperties(Instance: TObject);
begin
  CopyObject(self,Instance);
end;

function TDDDAppSettingsAbstract.WasModified: Boolean;
begin
  result := ObjectToJSON(self,[])<>fInitialJsonContent;
end;


{ TDDDLogSettings }

constructor TDDDLogSettings.Create;
begin
  inherited Create;
  fLevels := [low(TSynLogInfo)..high(TSynLogInfo)]; // "Levels":"*" by default
  fPerThread := ptIdentifiedInOnFile;
  fRotateFileAtHour := -1;
  fAutoFlush := 5;
end;


{ TDDDAppSettings }

constructor TDDDAppSettingsFile.Create(
  const aSettingsJsonFileName: TFileName);
begin
  inherited Create;
  if aSettingsJsonFileName<>'' then
    fSettingsJsonFileName := aSettingsJsonFileName else
    fSettingsJsonFileName := ChangeFileExt(ExeVersion.ProgramFileName,'.settings');
  fSettingsJsonFileName := ExpandFileName(fSettingsJsonFileName);
  SetJsonContent(Pointer(AnyTextFileToRawUTF8(fSettingsJsonFileName,true)));
end;

procedure TDDDAppSettingsFile.UpdateFile;
var new: RawUTF8;
begin
  if not WasModified then
    exit;
  new := ObjectToJSON(Self,[woHumanReadable,woStoreStoredFalse,
    woHumanReadableFullSetsAsStar,woHumanReadableEnumSetAsComment]);
  FileFromString(new,fSettingsJsonFileName);
end;

destructor TDDDAppSettingsFile.Destroy;
begin
  UpdateFile;
  inherited Destroy;
end;

procedure TDDDAppSettingsFile.Initialize(const aDescription: string);
begin
  with SQLite3Log.Family do begin
    Level := Log.Levels-[sllNone]; // '*' would include sllNone
    if Log.ConsoleLevels<>[] then
      EchoToConsole := Log.ConsoleLevels-[sllNone];
    PerThreadLog := Log.PerThread;
    if Log.DestinationPath<>'' then
     DestinationPath := Log.DestinationPath;
    RotateFileCount := Log.RotateFileCount;
    RotateFileSizeKB := Log.RotateFileSizeKB;
    RotateFileDailyAtHour := Log.RotateFileDailyAtHour;
    if Log.StackTraceViaAPI then
      StackTraceUse := stOnlyAPI;
    {$ifdef MSWINDOWS}
    AutoFlushTimeOut := Log.AutoFlushTimeOut;
    {$endif}
  end;
  if fDescription='' then
    fDescription := aDescription;
  ChDir(ExtractFilePath(SettingsJsonFileName));
end;

function TDDDAppSettingsFile.FileNameRelativeToSettingsFile(
  const aFileName: TFileName): TFileName;
var path,settings: TFileName;
begin
  path := ExtractFilePath(ExpandFileName(aFileName));
  settings := ExtractFilePath(ExpandFileName(SettingsJsonFileName));
  result := ExtractRelativePath(settings,path)+ExtractFileName(aFileName);
end;


{ TDDDRestSettings }

function TDDDRestSettings.NewRestInstance(aRootSettings: TDDDAppSettingsFile;
  aModel: TSQLModel; aOptions: TDDDNewRestInstanceOptions;
  aExternalDBOptions: TVirtualTableExternalRegisterOptions;
  aMongoDBOptions: TStaticMongoDBRegisterOptions): TSQLRest;
begin
  if aModel=nil then
     raise EDDDInfraException.CreateUTF8('%.NewRestInstance(aModel=nil)',[self]);
  if fRoot='' then // supplied TSQLModel.Root is the default root URI
    fRoot := aModel.Root else
    aModel.Root := fRoot;
  {$ifndef LINUX}
  if (fWrapperTemplateFolder='') and
     DirectoryExists('d:\dev\lib\CrossPlatform\Templates') then
    fWrapperTemplateFolder := 'd:/dev/lib/CrossPlatform/Templates';
  {$endif}
  if fORM.Kind='' then
    if riDefaultLocalSQlite3IfNone in aOptions then begin
      fORM.Kind := 'TSQLRestServerDB'; // SQlite3 engine by default
      if fORM.ServerName='' then
        fORM.ServerName := StringToUTF8(
          ChangeFileExt(ExtractFileName(ExeVersion.ProgramFileName),'.db'));
      if (aRootSettings<>nil) and (optStoreDBFileRelativeToSettings in Options) then
        fORM.ServerName := StringToUTF8(
          aRootSettings.FileNameRelativeToSettingsFile(UTF8ToString(fORM.ServerName)));
    end else
    if riDefaultInMemorySQLite3IfNone in aOptions then begin
      fORM.Kind := 'TSQLRestServerDB';
      fORM.ServerName := SQLITE_MEMORY_DATABASE_NAME;
    end else
    if riDefaultFullMemoryIfNone in aOptions then begin
      fORM.Kind := 'TSQLRestServerFullMemory';
    end;
  result := nil;
  try
    if fORM.Kind='' then
      exit;
    if (optEraseDBFileAtStartup in Options) and (fORM.ServerName<>'') then
      if (fORM.Kind='TSQLRestServerDB') or
         (fORM.Kind='TSQLRestServerFullMemory') then
        DeleteFile(UTF8ToString(fORM.ServerName));
    result := TSQLRestMongoDBCreate(aModel,ORM,
      riHandleAuthentication in aOptions,aMongoDBOptions);
    if result=nil then // failed to use MongoDB -> try external or internal DB
      result := TSQLRestExternalDBCreate(aModel,ORM,
        riHandleAuthentication in aOptions,aExternalDBOptions);
    if result=nil then
      exit; // no match or wrong parameters
    if result.InheritsFrom(TSQLRestServer) then begin
      if (WrapperTemplateFolder<>'') and DirectoryExists(WrapperTemplateFolderFixed) then
        AddToServerWrapperMethod(TSQLRestServer(result),[WrapperTemplateFolderFixed],
          WrapperSourceFolderFixed);
      if result.InheritsFrom(TSQLRestServerDB) then
        with TSQLRestServerDB(result).DB do begin // tune internal SQlite3 engine
          LockingMode := lmExclusive;
          if optSQlite3FileSafeSlowMode in Options then
            Synchronous := smNormal else
            Synchronous := smOff;
        end;
      if riCreateMissingTables in aOptions then
        TSQLRestServer(result).CreateMissingTables;
    end;
  finally
    if riOwnModel in aOptions then
      if result=nil then // avoid memory leak
        aModel.Free else
        aModel.Owner := result;
  end;
end;

function TDDDRestSettings.WrapperSourceFolderFixed: TFileName;
begin
  if fWrapperSourceFolders='' then
    result := '' else begin
    if fWrapperSourceFolderFixed='' then
      fWrapperSourceFolderFixed := StringReplace(fWrapperSourceFolders,'/','\',[rfReplaceAll]);
    result := fWrapperSourceFolders;
  end;
end;

function TDDDRestSettings.WrapperTemplateFolderFixed: TFileName;
begin
  if fWrapperTemplateFolder='' then
    result := '' else begin
    if fWrapperTemplateFolderFixed='' then
      fWrapperTemplateFolderFixed := StringReplace(fWrapperTemplateFolder,'/','\',[rfReplaceAll]);
    result := fWrapperTemplateFolder;
  end;
end;


{ TDDDAppSettingsRestFile }

procedure TDDDAppSettingsRestFile.Initialize(const aDescription: string);
begin
  inherited Initialize(aDescription);
  if ServerPort='' then
    ServerPort := {$ifdef LINUX}'8888'{$else}'888'{$endif};
end;


{ TDDDAdministratedDaemonSettings }

constructor TDDDAdministratedDaemonSettings.Create;
begin
  inherited Create;
  AuthRootURI := 'admin';
  AuthHttp.PasswordPlain := RawUTF8(ClassName); // default WebSocketPassword
end;


{ TDDDAdministratedDaemonSettingsFile }

procedure TDDDAdministratedDaemonSettingsFile.Initialize(
  const aDescription,aServiceName,aServiceDisplayName: string);
begin
  inherited Initialize(aDescription);
  if FServiceName='' then
    FServiceName := aServiceName;
  if FServiceDisplayName='' then
    FServiceDisplayName := aServiceDisplayName;
end;


{ TDDDSocketThreadSettings }

constructor TDDDSocketThreadSettings.Create;
begin
  inherited Create;
  FConnectionAttemptsInterval := 5;
  FMonitoringInterval := 30*1000; // log monitoring information every 30 seconds
end;

end.
