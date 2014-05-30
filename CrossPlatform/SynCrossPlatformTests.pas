/// regression tests for mORMot's cross-platform units
// - this unit is a part of the freeware Synopse mORMot framework,
// licensed under a MPL/GPL/LGPL tri-license; version 1.18
unit SynCrossPlatformTests;

{
    This file is part of Synopse mORMot framework.

    Synopse mORMot framework. Copyright (C) 2014 Arnaud Bouchez
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

  Portions created by the Initial Developer are Copyright (C) 2014
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
  - first public release, corresponding to mORMot Framework 1.18
  - would compile with Delphi for any platform, or with FPC or Kylix

}

{$i SynCrossPlatform.inc} // define e.g. HASINLINE

interface

uses
  SysUtils,
  Classes,
  Variants,
  TypInfo,
  SynCrossPlatformJSON,
  SynCrossPlatformRest;


type
  /// the prototype of an individual test
  // - to be used with TSynTest descendants
  TSynTestEvent = procedure of object;

{$M+} { we need the RTTI for the published methods of this object class }
  /// generic class for performing simple tests 
  // - purpose of this ancestor is to have RTTI for its published methods,
  // which will contain the tests
  TSynTest = class
  protected
    fFailureMsg: string;
    fCurrentTest: Integer;
  public
    /// the test case name
    Ident: string;
    /// the registered tests, i.e. all published methods of this class
    Tests: TPublishedMethodDynArray;
    /// how many Check() call did pass
    Passed: cardinal;
    /// how many Check() call did failed
    Failed: cardinal;
    /// create the test instance
    // - this constructor will add all published methods to the internal
    // test list, accessible via the Count/TestName/TestMethod properties
    constructor Create(const aIdent: string='');
    /// run all tests
    procedure Run(LogToConsole: boolean);
    /// validate a test
    procedure Check(test: Boolean; const Msg: string=''); overload;
  published
  end;
{$M-}

  /// regression tests of our CrossPlatform units
  TSynCrossPlatformTests = class(TSynTest)
  published
    procedure Iso8601DateTime;
    procedure Base64Encoding;
    procedure JSON;
    procedure Model;
  end;

implementation

type
  TSQLRecordPeople = class(TSQLRecord)
  private
    fData: TSQLRawBlob;
    fFirstName: RawUTF8;
    fLastName: RawUTF8;
    fYearOfBirth: integer;
    fYearOfDeath: word;
  published
    property FirstName: RawUTF8 read fFirstName write fFirstName;
    property LastName: RawUTF8 read fLastName write fLastName;
    property Data: TSQLRawBlob read fData write fData;
    property YearOfBirth: integer read fYearOfBirth write fYearOfBirth;
    property YearOfDeath: word read fYearOfDeath write fYearOfDeath;
  end;
  
  TMainNested = class(TCollectionItem)
  private
    fNumber: double;
    fIdent: RawUTF8;
  published
    property Ident: RawUTF8 read fIdent write fIdent;
    property Number: double read fNumber write fNumber;
  end;

  TMain = class(TPersistent)
  private
    fName: RawUTF8;
    fNested: TCollection;
  public
    constructor Create;
    destructor Destroy; override;
  published
    property Name: RawUTF8 read fName write fName;
    property Nested: TCollection read fNested;
  end;


{ TSynTest }

procedure TSynTest.Check(test: Boolean; const Msg: string='');
begin
  if test then
    inc(Passed) else begin
    inc(Failed);
    if Msg<>'' then
      fFailureMsg := fFailureMsg+'['+Msg+'] ';
  end;
end;

constructor TSynTest.Create(const aIdent: string);
begin
  Ident := aIdent;
  GetPublishedMethods(self,Tests);
end;

procedure TSynTest.Run(LogToConsole: boolean);
var i: integer;
    BeforePassed,BeforeFailed: cardinal;
    start: TDateTime;
    datetime: string;
    LogFile: text;
  procedure Log(const Fmt: string; const Args: array of const);
  var msg: string;
  begin
    msg := format(Fmt,Args);
    if LogToConsole then
      writeln(msg) else
      writeln(LogFile,msg);
    if not LogToConsole then
      Flush(LogFile);
  end;
begin
  start := Now;
  datetime := DateTimeToIso8601(start);
  if not LogToConsole then begin
    assign(LogFile,ExtractFilePath(ParamStr(0))+
      FormatDateTime('yyyy mm dd hh nn ss',start)+'.txt');
    rewrite(LogFile);
  end;
  Log(#13#10' %s'#13#10'%s',[Ident,StringOfChar('-',length(Ident)+2)]);
  for i := 0 to high(Tests) do begin
    Log(#13#10' %d. Running "%s"',[i+1,Tests[i].Name]);
    BeforePassed := Passed;
    BeforeFailed := Failed;
    try
      fCurrentTest := i;
      TSynTestEvent(Tests[i].Method)();
    except
      on E: Exception do
        Check(False,format('Exception %s raised with message "%s"',[E.ClassName,E.Message]));
    end;
    if Failed<>BeforeFailed then
      Log(' !!! %d test(s) failed / %d %s',[Failed-BeforeFailed,
        Failed-BeforeFailed+Passed-BeforePassed,fFailureMsg]) else
      Log('    %d tests passed',[Passed-BeforePassed]);
    fFailureMsg := '';
  end;
  Log(#13#10' Tests failed: %d / %d'#13#10' Time elapsed: %s'#13#10#13#10' %s',
    [Failed,Failed+Passed,FormatDateTime('nn:ss:zzz',Now-Start),datetime]);
  if not LogToConsole then
    close(LogFile);
end;


{ TSynCrossPlatformTests }

procedure TSynCrossPlatformTests.Base64Encoding;
var b,c: TByteDynArray;
    i: integer;
begin
  check(b=nil);
  for i := 0 to 100 do begin
    SetLength(b,i);
    if i>0 then
      b[i-1] := i;
    check(Base64JSONStringToBytes(BytesToBase64JSONString(b),c));
    check(length(c)=i);
    check(CompareMem(Pointer(b),pointer(c),i));
  end;
end;

procedure TSynCrossPlatformTests.Iso8601DateTime;
procedure Test(D: TDateTime);
var s: string;
procedure One(D: TDateTime);
var E: TDateTime;
    V: TTimeLog;
begin
  s := DateTimeToIso8601(D);
  E := Iso8601ToDateTime(s);
  Check(Abs(D-E)<(1000/MSecsPerDay)); // we allow 1 sec error
  Check(DateTimeToJSON(D)='"'+s+'"');
  V := DateTimeToTTimeLog(D);
  E := TTimeLogToDateTime(V);
  Check(Abs(D-E)<(1000/MSecsPerDay));
  Check(UrlDecode(UrlEncode(s))=s);
end;
begin
  One(D);
  Check(length(s)=19);
  One(Trunc(D));
  Check(length(s)=10);
  One(Frac(D));
  Check(length(s)=9);
end;
var D: TDateTime;
    i: integer;
begin
  D := Now/20+Random*20; // some starting random date/time
  for i := 1 to 2000 do begin
    Test(D);
    D := D+Random*57; // go further a little bit: change date/time
  end;
end;

procedure TSynCrossPlatformTests.JSON;
var doc: variant;
    json,json2,inlined: string;
    i: integer;
    obj1,obj2: TMain;
    item: TMainNested;
begin
  doc := JSONVariant('{"test":1234,"name":"Joh\"n\r","zero":0.0}');
  check(doc.test=1234);
  check(doc.name='Joh"n'#13);
  check(doc.name2=null);
  check(doc.zero=0);
  json := doc;
  check(json='{"test":1234,"name":"Joh\"n\r","zero":0}');
  {$ifdef FPC}
  TJSONVariantData(doc)['name2'] := 3.1415926;
  TJSONVariantData(doc)['name'] := 'John';
  {$else}
  doc.name2 := 3.1415926;
  doc.name := 'John';
  {$endif}
  json := doc;
  check(json='{"test":1234,"name":"John","zero":0,"name2":3.1415926}');
  check(IsRowID('id'));
  check(IsRowID('iD'));
  check(IsRowID('rowid'));
  check(IsRowID('RowID'));
  check(not IsRowID('iz'));
  check(not IsRowID('i2'));
  check(not IsRowID('rawid'));
  check(not IsRowID(''));
  check(FormatBind('',[])='');
  for i := 1 to 1000 do begin
    json := IntToStr(i);
    inlined := ':('+json+'):';
    check(FormatBind(json,[])=json);
    check(FormatBind(json,[i])=json);
    check(FormatBind('?',[i])=inlined);
    check(FormatBind('a?a',[i])='a'+inlined+'a');
    check(FormatBind('a?',[i])='a'+inlined);
    check(FormatBind('?a',[i])=inlined+'a');
    check(FormatBind('ab?',[i])='ab'+inlined);
    check(FormatBind('?ab',[i])=inlined+'ab');
    check(FormatBind('ab?ab',[i])='ab'+inlined+'ab');
    check(FormatBind('abc?abc',[i])='abc'+inlined+'abc');
    check(FormatBind('abc?abc',[i,1])='abc'+inlined+'abc');
    check(FormatBind(json+'?',[i])=json+inlined);
    check(FormatBind('?'+json,[i])=inlined+json);
    check(FormatBind('ab?ab',[json])='ab:("'+json+'"):ab');
    check(FormatBind('ab?ab',[variant(json)])='ab:("'+json+'"):ab');
    check(FormatBind('ab?ab',[variant(i)])='ab'+inlined+'ab');
    check(FormatBind('ab?ab?',[variant(i)])='ab'+inlined+'ab:(null):');
    check(FormatBind('ab?ab??cd',[i,i,json])='ab'+inlined+'ab'+inlined+
      ':("'+json+'"):cd');
  end;
  obj1 := TMain.Create;
  obj2 := TMain.Create;
  try
    for i := 1 to 100 do begin
      obj1.Name := IntToStr(i);
      item := obj1.Nested.Add as TMainNested;
      item.Ident := obj1.Name;
      item.Number := i/2;
      check(obj1.Nested.Count=i);
      json := ObjectToJSON(obj1);
      check(json<>'');
      if i=1 then
        check(json='{"Name":"1","Nested":[{"Ident":"1","Number":0.5}]}');
      JSONToObject(obj2,json);
      check(obj2.Nested.Count=i);
      json2 := ObjectToJSON(obj2);
      check(json2=json);
    end;
  finally
    obj2.Free;
    obj1.Free;
  end;
  json := 'one,two,3';
  i := 1;
  check(GetNextCSV(json,i,json2));
  check(json2='one');
  check(GetNextCSV(json,i,json2));
  check(json2='two');
  check(GetNextCSV(json,i,json2));
  check(json2='3');
  check(not GetNextCSV(json,i,json2));
  check(not GetNextCSV(json,i,json2));
  json := 'one';
  i := 1;
  check(GetNextCSV(json,i,json2));
  check(json2='one');
  check(not GetNextCSV(json,i,json2));
  json := '';
  i := 1;
  check(not GetNextCSV(json,i,json2));
end;

procedure TSynCrossPlatformTests.Model;
var Model: TSQLModel;
    people: TSQLRecordPeople;
    i: integer;
    json: string;
    fields: TSQLFieldBits;
begin
  Model := TSQLModel.Create([TSQLRecordPeople],'test/');
  Check(Model.Root='test');
  Check(length(Model.Info)=1);
  Check(Model.Info[0].Table=TSQLRecordPeople);
  Check(Model.Info[0].Name='People');
  Check(length(Model.Info[0].Prop)=6);
  people := TSQLRecordPeople.Create;
  try
    for i := 1 to 1000 do begin
      people.ID := i;
      people.FirstName := IntToStr(i);
      people.LastName := people.FirstName+people.FirstName;
      people.YearOfBirth := i+500;
      people.YearOfDeath := people.YearOfBirth+40;
      json := ObjectToJSON(people);
      check(json=Format('{"ID":%d,"FirstName":"%d","LastName":"%d%d",'+
        '"Data":"","YearOfBirth":%d,"YearOfDeath":%d}',[i,i,i,i,i+500,i+540]));
    end;
  finally
    people.Free;
  end;
  Check(PInteger(@Model.Info[0].SimpleFields)^=$37);
  Check(PInteger(@Model.Info[0].BlobFields)^=8);
  fields := Model.Info[0].FieldNamesToFieldBits('');
  Check(PInteger(@fields)^=$37);
  fields := Model.Info[0].FieldNamesToFieldBits('*');
  Check(PInteger(@fields)^=-1);
  fields := Model.Info[0].FieldNamesToFieldBits('RowID,firstname');
  Check(PInteger(@fields)^=3);
  Check(Model.Info[0].FieldBitsToFieldNames(fields)='RowID,FirstName');
  fields := Model.Info[0].FieldNamesToFieldBits('firstname,id,toto');
  Check(PInteger(@fields)^=3);
  Check(Model.Info[0].FieldBitsToFieldNames(fields)='RowID,FirstName');
  Model.Free;
end;


{ TMain }

constructor TMain.Create;
begin
  inherited;
  fNested := TCollection.Create(TMainNested);
end;

destructor TMain.Destroy;
begin
  fNested.Free;
  inherited;
end;

initialization

end.