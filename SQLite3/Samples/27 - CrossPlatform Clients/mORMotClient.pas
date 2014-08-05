/// remote access to a mORMot server using SynCrossPlatform* units
// - retrieved from http://localhost:888/root/wrapper/CrossPlatform/mORMotClient.pas
// at 2014-08-05 11:54:50 using "CrossPlatform.pas.mustache" template
unit mORMotClient;

{
  WARNING:
    This unit has been generated by a mORMot 1.18 server.
    Any manual modification of this file may be lost after regeneration.

  Synopse mORMot framework. Copyright (C) 2014 Arnaud Bouchez
    Synopse Informatique - http://synopse.info

  This unit is released under a MPL/GPL/LGPL tri-license,
  and therefore may be freely included in any application.
}

interface

uses
  SynCrossPlatformJSON,
  SynCrossPlatformSpecific,
  SynCrossPlatformREST;
  

type // define some enumeration types, used below
  TPeopleSexe = (sFemale, sMale);
  TRecordEnum = (reOne, reTwo, reLast);

type // define some record types, used as properties below
  TTestCustomJSONArraySimpleArray = record
    F: string;
    G: array of string;
    H: record
      H1: integer;
      H2: string;
      H3: record
        H3a: boolean;
        H3b: TSQLRawBlob;
      end;
    end;
    I: TDateTime;
    J: array of record
      J1: byte;
      J2: TGUID;
      J3: TRecordEnum;
    end;
  end;


type
  /// service accessible via http://localhost:888/root/Calculator
  // - this service will run in sicShared mode
  TServiceCalculator = class(TServiceClientAbstract)
  public
    constructor Create(aClient: TSQLRestClientURI); override;
    function Add(const n1: integer; const n2: integer): integer;
    procedure ToText(const Value: currency; const Curr: string; var Sexe: TPeopleSexe; var Name: string);
    function RecordToText(var Rec: TTestCustomJSONArraySimpleArray): string;
  end;

  /// map "People" table
  TSQLRecordPeople = class(TSQLRecord)
  protected
    fFirstName: string; 
    fLastName: string; 
    fData: TSQLRawBlob; 
    fYearOfBirth: integer; 
    fYearOfDeath: word; 
    fSexe: TPeopleSexe; 
    fSimple: TTestCustomJSONArraySimpleArray; 
  public
    property Simple: TTestCustomJSONArraySimpleArray read fSimple write fSimple;
  published
    property FirstName: string read fFirstName write fFirstName;
    property LastName: string read fLastName write fLastName;
    property Data: TSQLRawBlob read fData write fData;
    property YearOfBirth: integer read fYearOfBirth write fYearOfBirth;
    property YearOfDeath: word read fYearOfDeath write fYearOfDeath;
    property Sexe: TPeopleSexe read fSexe write fSexe;
  end;
  

/// return the database Model corresponding to this server
function GetModel: TSQLModel;

const
  /// the server port, corresponding to http://localhost:888
  SERVER_PORT = 888;


implementation


{ Some helpers for enumerates types }

function Variant2TPeopleSexe(const _variant: variant): TPeopleSexe;
begin
  result := TPeopleSexe(VariantToEnum(_variant,['sFemale','sMale']));
end;

function Variant2TRecordEnum(const _variant: variant): TRecordEnum;
begin
  result := TRecordEnum(VariantToEnum(_variant,['reOne','reTwo','reLast']));
end;


{ Some helpers for record types:
  due to potential obfuscation of generated JavaScript, we can't assume
  that the JSON used for transmission would match record fields naming }

function Variant2TTestCustomJSONArraySimpleArray(const _variant: variant): TTestCustomJSONArraySimpleArray;
var i: integer;
    _a: integer;
    _arr: PJSONVariantData;
begin
  result.F := _variant.F;
  SetLength(result.G,JSONVariantDataSafe(_variant.G)^.Count);
  for i := 0 to high(result.G) do
    result.G[i] := JSONVariantDataSafe(_variant.G)^.Item[i];
  result.H.H1 := _variant.H.H1;
  result.H.H2 := _variant.H.H2;
  result.H.H3.H3a := _variant.H.H3.H3a;
  result.H.H3.H3b := VariantToBlob(_variant.H.H3.H3b);
  result.I := Iso8601ToDateTime(_variant.I);
  _arr := JSONVariantDataSafe(_variant.J);
  if _arr.Kind=jvArray then begin
    SetLength(result.J,_arr.Count);
    for _a := 0 to _arr.Count-1 do
    with result.J[_a] do begin
      J1 := _arr.Values[_a].J1;
      J2 := VariantToGUID(_arr.Values[_a].J2);
      J3 := Variant2TRecordEnum(_arr.Values[_a].J3);
    end;
  end;
end;

function TTestCustomJSONArraySimpleArray2Variant(const _record: TTestCustomJSONArraySimpleArray): variant;
var i: integer;
    res: TJSONVariantData;
begin
  res.Init;
  res.SetPath('F',_record.F);
  with res.EnsureData('G')^ do
    for i := 0 to high(_record.G) do
      AddValue(_record.G[i]);
  res.SetPath('H.H1',_record.H.H1);
  res.SetPath('H.H2',_record.H.H2);
  res.SetPath('H.H3.H3a',_record.H.H3.H3a);
  res.SetPath('H.H3.H3b',BlobToVariant(_record.H.H3.H3b));
  res.SetPath('I',DateTimeToIso8601(_record.I));
  with res.EnsureData('J')^ do
    for i := 0 to high(_record.J) do
    with AddItem^, _record.J[i] do begin
      AddNameValue('J1',J1);
      AddNameValue('J2',GUIDToVariant(J2));
      AddNameValue('J3',ord(J3));
    end;
  result := variant(res);
end;

function GetModel: TSQLModel;
begin
  result := TSQLModel.Create([TSQLAuthUser,TSQLAuthGroup,TSQLRecordPeople],'root');
end;


{ TServiceCalculator }

constructor TServiceCalculator.Create(aClient: TSQLRestClientURI);
begin
  fServiceName := 'Calculator';
  fServiceURI := 'Calculator';
  fInstanceImplementation := sicShared;
  fContractExpected := 'D9CD85D75F8AE460';
  inherited Create(aClient);
end;

function TServiceCalculator.Add(const n1: integer; const n2: integer): integer;
var res: TVariantDynArray;
begin
  fClient.CallRemoteService(self,'Add',1, // raise EServiceException on error
    [n1,n2],res);
  Result := res[0];
end;

procedure TServiceCalculator.ToText(const Value: currency; const Curr: string; var Sexe: TPeopleSexe; var Name: string);
var res: TVariantDynArray;
begin
  fClient.CallRemoteService(self,'ToText',2, // raise EServiceException on error
    [Value,Curr,ord(Sexe),Name],res);
  Sexe := TPeopleSexe(res[0]);
  Name := res[1];
end;

function TServiceCalculator.RecordToText(var Rec: TTestCustomJSONArraySimpleArray): string;
var res: TVariantDynArray;
begin
  fClient.CallRemoteService(self,'RecordToText',2, // raise EServiceException on error
    [TTestCustomJSONArraySimpleArray2Variant(Rec)],res);
  Rec := Variant2TTestCustomJSONArraySimpleArray(res[0]);
  Result := res[1];
end;


end.