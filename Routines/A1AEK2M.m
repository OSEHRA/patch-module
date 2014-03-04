A1AEK2M ; VEN/SMH - Load an HFS KIDS file into the Patch Module;2014-03-04  3:04 PM
 ;;2.4;PATCH MODULE;
 ;
 ; Based on code written by Dr. Cameron Schlehuber.
 ;
 ; Notes on the KIDS format and conversion procedure.
 ; NB: Notes moved to A1AEK2M0 to make space in this routine.
 ;
 ; TODO: File package entry into our system if it can't be found
 ;       - Hint: Finds KIDS EP that does the PKG subs
 ;
DBAKID2M ; Restore patches from HFS files to MailMan
 ; Get path to HFS patches
 ; Order through all messages
 N OLDDUZ S OLDDUZ=DUZ ; Keep for ^DISV
 ; N DUZ S DUZ=.5,DUZ(0)="" ; Save DUZ from previous caller.
 N DIR,X,Y,DIROUT,DIRUT,DTOUT,DUOUT,DIROUT ; fur DIR
 S DIR(0)="F^2:255",DIR("A")="Full path of patches to load, up to but not including patch names"
 S DIR("B")=$G(^DISV(OLDDUZ,"A1AEK2M-SB"))
 D ^DIR
 QUIT:Y="^"
 N ROOT S ROOT("SB")=Y  ; where we load files from... Single Build Root
 S ^DISV(OLDDUZ,"A1AEK2M-SB")=Y
 ;
 S DIR(0)="F^2:60",DIR("A")="Full path of Multibuilds directory, in case I can't find a patch"
 S DIR("B")=$G(^DISV(OLDDUZ,"A1AEK2M-MB"))
 D ^DIR
 QUIT:Y="^"
 S ROOT("MB")=Y ; Multi Build Root
 S ^DISV(OLDDUZ,"A1AEK2M-MB")=Y
 ;
SILENT ; Don't talk. Pass ROOT in Symbol Table.
 ; Fall through from above, but can be silently called if you pass ROOT in ST.
 ; All output is sent via EN^DDIOL. Set DIQUIET to redirect to a global.
 N FILES ; retrun array
 ;
 ; Load text files first
 N ARRAY
 S ARRAY("*.TXT")=""
 S ARRAY("*.txt")=""
 N Y S Y=$$LIST^%ZISH(ROOT("SB"),"ARRAY","FILES") I 'Y W !,"Error getting directory list" QUIT
 ;
 ; Loop through each text patches.
 N ERROR
 N PATCH S PATCH=""
 N CANTLOAD ; Patches for whom we cannot find a KIDS file
 F  S PATCH=$O(FILES(PATCH)) Q:PATCH=""  D LOAD(.ROOT,PATCH,.ERROR,.CANTLOAD) Q:$D(ERROR)
 ;
 ; Print out the patches we couldn't find.
 I $D(CANTLOAD) D
 . N I S I=""
 . F  S I=$O(CANTLOAD(I)) Q:I=""  D EN^DDIOL("Patch "_I_" from "_CANTLOAD(I)_" doesn't have a KIDS file")
 . D EN^DDIOL("Please load these KIDS files manually into the patch module.")
 QUIT
 ;
LOAD(ROOT,PATCH,ERROR,CANTLOAD) ; Load TXT message, find KIDS, then load KIDS and mail.
 ; ROOT = File system directory (Ref)
 ; PATCH = File system .TXT patch name (including the .TXT) (Value)
 ; ERROR = Ref variable to indicate error.
 ; CANTLOAD = Ref variable containing the KIDS patches we can't load b/c we can't find them.
 ;
 ; NB: I start from 2 just in case there is something I need to put in 1 (like $TXT)
 K ^TMP($J,"TXT")
 D EN^DDIOL("Loading description "_PATCH)
 N Y S Y=$$FTG^%ZISH(ROOT("SB"),PATCH,$NA(^TMP($J,"TXT",2,0)),3) I 'Y W !,"Error copying TXT to global" S ERROR=1 Q
 D CLEANHF^A1AEK2M0($NA(^TMP($J,"TXT"))) ; add $TXT/$END TXT if necessary
 ;
 ; Analyze message and extract data from it.
 N RTN ; RPC style return
 ;
 ;
 ; N OET S OET=$ET
 N $ET,$ES S $ET="D ANATRAP^A1AEK2M2(PATCH)" ; try/catch
 D ANALYZE^A1AEK2M2(.RTN,$NA(^TMP($J,"TXT")))
 ; S $ET=OET
 ; K OET
 ;
 K ^TMP($J,"MSG") ; Message array eventually to be mailed.
 ;
 ; Move the description into the msg array, making sure we have room for the $TXT.
 N I F I=0:0 S I=$O(RTN("DESC",I)) Q:'I  S ^TMP($J,"MSG",I+1,0)=RTN("DESC",I)
 S ^TMP($J,"MSG",1,0)=RTN("$TXT") ; $TXT
 N LS S LS=$O(^TMP($J,"MSG"," "),-1)
 S ^TMP($J,"MSG",LS+1,0)="$END TXT" ; $END TXT
 K I,LS
 ;
 N LASTSUB S LASTSUB=$O(^TMP($J,"TXT"," "),-1)
 ;
 ; Info only patch?
 N INFOONLY S INFOONLY=0 ; Info Only patch?
 N I F I=0:0 S I=$O(RTN("CAT",I)) Q:'I  I RTN("CAT",I)="Informational" S INFOONLY=1
 N I F I=0:0 S I=$O(RTN("CAT",I)) Q:'I  I RTN("CAT",I)="Routine" S INFOONLY=0   ; B/c somebody might screw up by adding addtional stuff.
 K I
 ;
 I INFOONLY D EN^DDIOL(PATCH_" is an Info Only patch.")
 ;
 ; Load KIDS message starting into the last subscript + 1 from the text node
 ; Only if not informational!!! -- THIS CHANGED NOW B/C VA HAS SOME PATCHES THAT ARE INFORMATIONAL AND HAVE KIDS BUILDS
 K ^TMP($J,"KID")
 N KIDFIL S KIDFIL=$$KIDFIL^A1AEK2M0(.ROOT,PATCH,.RTN,$NA(^TMP($J,"KID"))) ; Load the KIDS file
 I KIDFIL="",'INFOONLY S CANTLOAD(RTN("DESIGNATION"))=PATCH ; if we can't find it, and it isn't info, put it in this array.
 ;
 ; If we loaded the KIDS build, move it over.
 I $D(^TMP($J,"KID")) D
 . N I F I=1:1 Q:'$D(^TMP($J,"KID",I))  S ^TMP($J,"MSG",LASTSUB+I,0)=^TMP($J,"KID",I)
 ; 
 ; debug
 ; S $ET="B"
 ; debug
 ;
 ; Add dependencies in description (temporary or permanent... I don't know now).
 I $O(RTN("PREREQ","")) D                              ; If we have prerequisites
 . N LS S LS=$O(RTN("DESC"," "),-1)                    ; Get last sub
 . N NS S NS=LS+1                                      ; New Sub
 . S RTN("DESC",NS)=" ",NS=NS+1                        ; Empty line
 . S RTN("DESC",NS)="Associated patches:",NS=NS+1      ; Put the data into (this line and next)
 . N I F I=1:1 Q:'$D(RTN("PREREQ",I))  S RTN("DESC",NS)=" - "_RTN("PREREQ",I),NS=NS+1
 ;
 ; Change designation into Patch Module format from KIDS format
 S RTN("DESIGNATION")=$$K2PMD(RTN("DESIGNATION"))
 ; ZEXCEPT: A1AEPKIF is created by PKGADD in the ST.
 D PKGADD(RTN("DESIGNATION"))            ; Add to Patch Module Package file
 D PKGSETUP(A1AEPKIF,.RTN)               ; And set it up.
 D VERSETUP(A1AEPKIF,RTN("DESIGNATION")) ; Add its version; ZEXCEPT: A1AEVR - Version leaks
 N DA S DA=$$ADDPATCH(A1AEPKIF,A1AEVR,.RTN,$NA(^TMP($J,"MSG")),$D(CANTLOAD(RTN("DESIGNATION"))),INFOONLY)  ; ZEXCEPT: A1AENB,A1AEPD
 D ASSERT(DA)                            ; Assert that we obtained an IEN
 D ASSERT($P(RTN("DESIGNATION"),"*",3)=A1AENB) ; Assert that the Number is the same as the patch number
 D ASSERT(RTN("DESIGNATION")=A1AEPD) ; Assert that the designation is the same as the Patch Designation
 ; 
 ; Now, add the Primary forked version of the patch
 N DA D
 . N DERIVEDPATCH M DERIVEDPATCH=RTN
 . N PRIM S PRIM=$$PRIMSTRM^A1AEUTL()
 . S DERIVEDPATCH("ORIG-DESIGNATION")=DERIVEDPATCH("DESIGNATION")
 . S $P(DERIVEDPATCH("DESIGNATION"),"*",3)=$P(DERIVEDPATCH("DESIGNATION"),"*",3)+PRIM-1
 . S DA=$$ADDPATCH(A1AEPKIF,A1AEVR,.DERIVEDPATCH,$NA(^TMP($J,"MSG")),$D(CANTLOAD(RTN("DESIGNATION"))),INFOONLY)  ; ZEXCEPT: A1AENB,A1AEPD
 . D ASSERT(DA)                            ; Assert that we obtained an IEN
 . D ASSERT($$GET1^DIQ(11005,DA,5.2)=DERIVEDPATCH("ORIG-DESIGNATION")) ; Original designation should be retained in derived field
 . D EN^DDIOL("Forked "_DERIVEDPATCH("ORIG-DESIGNATION")_" into "_DERIVEDPATCH("DESIGNATION"))
 ; 
 ;
 ; Deliver the message
 ; DON'T DO THIS ANYMORE -- WILL DELETE
 ; N XMERR,XMZ
 ; D SENDMSG^XMXAPI(.5,XMSUBJ,$NA(^TMP($J,"MSG")),"XXX@Q-PATCH.OSEHRA.ORG",,.XMZ) ; after
 ; I $D(XMERR) W !,"MailMan error, see ^TMP(""XMERR"",$J)" S ERROR=1 Q
 ; Set MESSAGE TYPE to KIDS build
 ; S $P(^XMB(3.9,XMZ,0),"^",7)="K"
 ;
 ; Kill temp globals
 K ^TMP($J,"KID"),^("TXT"),^("MSG")
 ;
 QUIT
 ;
K2PMD(PATCH) ; Private to package; $$; Kids to Patch Module designation. Code by Wally from A1AEHSVR.
 N %
 I PATCH[" " S %=$L(PATCH," "),PATCH=$P(PATCH," ",1,%-1)_"*"_$P(PATCH," ",%)_"*0"
 I $L(PATCH,"*")=3 S $P(PATCH,"*",2)=+$P(PATCH,"*",2)
 Q PATCH
 ;
PKGADD(DESIGNATION) ; Proc; Private to this routine; Add package to Patch Module
 ; Input: Designation: Patch designation AAA*1*22; By value
 ; ZEXCEPT: A1AEPK,A1AEPKIF,A1AEPKNM - Created by PKG^A1AEUTL
 ;
 ; When doing lookups for laygo, only look in the Package file's C index for designation.
 N DIC S DIC("PTRIX",11007,.01,9.4)="C"
 N A1AE S A1AE(0)="XLM" ; eXact match, Laygo, Multiple Indexes
 N X S X=$P(DESIGNATION,"*") ; Input to ^DIC
 D PKG^A1AEUTL
 ; ZEXCEPT: Y leaks from PKG^A1AEUTL
 I $P($G(Y),U,3) D EN^DDIOL("Added Package "_DESIGNATION_" to "_$P(^A1AE(11007,0),U))
 ;
 ; Check that the output variables from PKG^A1AEUTL are defined.
 D ASSERT(A1AEPKIF) ; Must be positive
 D ASSERT(A1AEPK=$P(DESIGNATION,"*")) ; PK must be the AAA
 D ASSERT($L(A1AEPKNM)) ; Must be defined.
 QUIT
 ;
PKGSETUP(A1AEPKIF,TXTINFO) ; Private; Setup package in Patch module
 ; ZEXCEPT: A1AEPKIF - Created by PKGADD
 N IENS S IENS=A1AEPKIF_","
 N A1AEFDA,DIERR
 S A1AEFDA(11007,IENS,2)="NO" ; USER SELECTION PERMITTED//^S X="NO"
 S A1AEFDA(11007,IENS,4)="NO" ; FOR TEST SITE ONLY?//^S X="NO"
 S A1AEFDA(11007,IENS,5)="YES" ; ASK PATCH DESCRIPTION COPY
 D FILE^DIE("EKT",$NA(A1AEFDA)) ; External, lock, transact
 I $D(DIERR) S $EC=",U-FILEMAN-ERROR,"
 ;
 N A1AEFDA
 S A1AEFDA(11007.02,"?+1,"_IENS,.01)="`"_$$MKUSR(TXTINFO("VER"),"A1AE PHVER")  ; SUPPORT PERSONNEL
 S A1AEFDA(11007.02,"?+1,"_IENS,2)="V"  ; VERIFY PERSONNEL
 S A1AEFDA(11007.03,"?+2,"_IENS,.01)="`"_$$MKUSR(TXTINFO("DEV"),"A1AE DEVELOPER") ; DEVELOPMENT PERSONNEL
 S A1AEFDA(11007.03,"?+3,"_IENS,.01)="`"_$$MKUSR(TXTINFO("COM"),"A1AE DEVELOPER") ; DITTO
 D UPDATE^DIE("E",$NA(A1AEFDA))
 I $D(DIERR) S $EC=",U-FILEMAN-ERROR,"
 D ASSERT($D(^A1AE(11007,A1AEPKIF,"PB")))  ; Verifier Nodes
 D ASSERT($D(^A1AE(11007,A1AEPKIF,"PH")))  ; Developer Nodes
 QUIT
 ;
MKUSR(NAME,KEY) ; Private; Make Users for the Package
 Q:$O(^VA(200,"B",NAME,0)) $O(^(0)) ; Quit if the entry exists with entry
 ;
 ; Get initials
 D STDNAME^XLFNAME(.NAME,"CP")
 N INI S INI=$E(NAME("GIVEN"))_$E(NAME("MIDDLE"))_$E(NAME("FAMILY"))
 ;
 ; File user with key
 N A1AEFDA,A1AEIEN,A1AEERR,DIERR
 S A1AEFDA(200,"?+1,",.01)=NAME ; Name
 S A1AEFDA(200,"?+1,",1)=INI ; Initials
 S A1AEFDA(200,"?+1,",28)="NONE" ; Mail Code
 S:$L($G(KEY)) A1AEFDA(200.051,"?+3,?+1,",.01)="`"_$O(^DIC(19.1,"B",KEY,""))
 ;
 N DIC S DIC(0)="" ; An XREF in File 200 requires this.
 D UPDATE^DIE("E",$NA(A1AEFDA),$NA(A1AEIEN),$NA(A1AEERR)) ; Typical UPDATE
 I $D(DIERR) S $EC=",U-FILEMAN-ERROR,"
 ;
 Q A1AEIEN(1) ;Provider IEN
 ;
VERSETUP(A1AEPKIF,DESIGNATION) ; Private; Setup version in 11007
 ; Input: - A1AEPKIF - Package IEN in 11007, value
 ;        - DESIGNATION - Package designation (XXX*1*3)
 ; Output: (In symbol table:) A1AEVR
 ; ZEXCEPT: A1AEVR - Created here by VER^A1AEUTL
 N X,A1AE S A1AE(0)="L" ; X is version number; input to ^DIC
 S X=$P(DESIGNATION,"*",2)
 D VER^A1AEUTL ; Internal API
 D ASSERT(A1AEVR=$P(DESIGNATION,"*",2))
 QUIT
 ;
ADDPATCH(A1AEPKIF,A1AEVR,TXTINFO,PATCHMSG,KIDMISSING,INFOONLY) ; Private $$ ; Add patch to 11005
 ; Input: TBD
 ; Non-importing version is at NUM^A1AEUTL
 N DESIGNATION S DESIGNATION=TXTINFO("DESIGNATION")
 ; Don't add a patch if it already exists in the system
 I $D(^A1AE(11005,"B",DESIGNATION)) DO   QUIT $O(^(DESIGNATION,""))
 . D EN^DDIOL($$RED^A1AEK2M1("Patch already exists. Not adding again."))
 . S A1AENB=$P(DESIGNATION,"*",3) ; leak this
 . S A1AEPD=DESIGNATION ; and also this
 ;
 N X S X=DESIGNATION
 S A1AENB=$P(DESIGNATION,"*",3) ; ZEXCEPT: A1AENB leak this
 N A1AETY S A1AETY="PH"
 N A1AEFL S A1AEFL=11005
 N DIC,Y S DIC(0)="LX" ; Laygo, Exact match
 ; ZEXCEPT: DA,A1AEPD Leaked by A1AEUTL
 I $D(TXTINFO("ORIG-DESIGNATION")) D  ; Derived patch!!
 . D SETNUM^A1AEUTL   ; This adds the patch based on the latest patch number
 . N FDA S FDA(11005,DA_",",5.2)=TXTINFO("ORIG-DESIGNATION")                ; Derived from patch field
 . N DIERR D FILE^DIE("E",$NA(FDA)) I $D(DIERR) S $EC=",U-FILEMAN-ERROR,"   ; File--external b/c this is a pointer.
 E  D SETNUM1^A1AEUTL ; This forces the current patch number in. 
 ;
 ; Lock the record
 LOCK +^A1AE(11005,DA):0 E  S $EC=",U-FAILED-TO-LOCK," ; should never happen
 ;
 ; Put stream
 N STREAM S STREAM=$$GETSTRM^A1AEK2M0(DESIGNATION) ; PATCH STREAM
 N FDA S FDA(11005,DA_",",.2)=STREAM
 N DIERR
 D FILE^DIE("",$NA(FDA),$NA(ERR))
 I $D(DIERR) S $EC=",U-FILEMAN-ERROR,"
 ;
 ; Change status to Under Development and add developer in
 ; TODO: If we have time, do this the proper way with Fileman APIs.
 S $P(^A1AE(11005,DA,0),U,8)="u"
 ;
 ; Get developer
 N DEV
 N NAME S NAME=TXTINFO("DEV")
 D STDNAME^XLFNAME(.NAME) ; Remove funny stuff (like dots at the end)
 S DEV=$$FIND1^DIC(200,"","QX",NAME,"B") ; Get developer
 ;
 D ASSERT(DEV,"Developer "_TXTINFO("DEV")_" couldn't be resolved")
 ;
 S $P(^A1AE(11005,DA,0),U,9)=DEV
 ; File Date
 N X,Y S X=TXTINFO("DEV","DATE") D ^%DT
 S $P(^A1AE(11005,DA,0),U,12)=Y
 ; Hand cross-reference
 S ^A1AE(11005,"AS",A1AEPKIF,A1AEVR,"u",A1AENB,DA)=""
 ;
 ; Add subject and priority and a default and sequenece number
 N FDA,IENS
 N DIERR
 S IENS=DA_","
 S FDA(11005,IENS,"PATCH SUBJECT")=TXTINFO("SUBJECT")
 S FDA(11005,IENS,"PRIORITY")=TXTINFO("PRIORITY")
 S FDA(11005,IENS,"DISPLAY ROUTINE PATCH LIST")="Yes"
 D FILE^DIE("E",$NA(FDA)) I $D(DIERR) S $EC=",U-FILEMAN-ERROR,"
 I $D(DIERR) S $EC=",U-FILEMAN-ERROR,"
 ;
 ; Get Categories from DD (abstractable function; maybe do that)
 N CATDD D FIELD^DID(11005.05,.01,,"POINTER",$NA(CATDD))  ; Categories DD
 N CATS ; Categories
 ; d:DATA DICTIONARY;i:INPUT TEMPLATE;
 N I F I=1:1:$L(CATDD("POINTER"),";") D        ; for each
 . N CATIE S CATIE=$P(CATDD("POINTER"),";",I)  ; each
 . Q:CATIE=""                                  ; last piece is empty. Make sure we aren't tripped up.
 . N EXT,INT                                   ; External Internal forms
 . S INT=$P(CATIE,":"),EXT=$P(CATIE,":",2)     ; get these
 . S CATS(EXT)=INT                             ; set into array for use below
 K CATDD
 ;
 N FDA
 N I F I=1:1 Q:'$D(TXTINFO("CAT",I))  D        ; for each
 . N CAT S CAT=TXTINFO("CAT",I)                ; each
 . S CAT=$$UP^XLFSTR(CAT)                      ; uppercase. PM Title cases them.
 . I CAT["ENHANCE" S CAT=$P(CAT," ")           ; Remove parens from 'Enhancement (Mandatory)'
 . N INTCAT S INTCAT=CATS(CAT)                 ; Internal Category
 . S FDA(11005.05,"+"_I_","_IENS,.01)=INTCAT   ; Addition FDA
 N DIERR                                       ; Fileman error flag
 D UPDATE^DIE("",$NA(FDA),$NA(ERR))            ; Add data
 I $D(DIERR) S $EC=",U-FILEMAN-ERROR,"         ; Chk for error
 D ASSERT($O(^A1AE(11005,+IENS,"C",0)))        ; Assert that there is at least one.
 K FDA
 K CATS                                        ; don't need this anymore
 ;
 ; Add Description to the patch
 ; Reference code is COPY^A1AECOPD, but this time we use Fileman
 ;
 ; Now put in the whole WP field in the file.
 N DIERR
 D WP^DIE(11005,IENS,5.5,"",$NA(TXTINFO("DESC")),$NA(ERR))
 I $D(DIERR) S $EC=",U-FILEMAN-ERROR,"         ; Chk for error
 D ASSERT($O(^A1AE(11005,DA,"D",0))>0) ; Assert that it was copied into PATCH DESCRIPTION
 ;
 ; Now, load the full KIDS build
 ; Reference code: ^A1AEM1
 ;
 ; 1st Create stub entry in 11005.1, whether or not we have KIDS file to populate
 NEW DIC,X,DINUM,DD,DO,DE,DQ,DR
 S DIC(0)="L"
 S (X,DINUM)=DA,DIC="^A1AE(11005.1,",DIC("DR")="20///"_"No routines included" K DD,DO D FILE^DICN K DE,DQ,DR,DIC("DR")
 ;
 ; Now load either the KIDS file or the HFS data from the remote system that was sent to us
 I 'INFOONLY D                            ; Must be a patch with KIDS contents
 . I KIDMISSING D HFS2^A1AEM1(DA)         ; No KIDS file found ; NB: Deletes 2 node (field 20) on 11005.1
 . E  D                                   ; We have a KIDS file
 . . S $P(^A1AE(11005.1,DA,0),"^",11)="K" ; FND+19  ; Type of message is KIDS not DIFROM
 . . K ^A1AE(11005.1,DA,2)                ; TRASH+7 ; remove old KIDS build
 . . MERGE ^A1AE(11005.1,DA,2)=@PATCHMSG  ; FND+23  ; Load the new one in.
 . . N X,Y S X=TXTINFO("DEV","DATE") D ^%DT         ; Get developer send date
 . . S $P(^A1AE(11005.1,DA,2,0),"^",5)=Y  ; FND+29  ; ditto
 . . S $P(^A1AE(11005.1,DA,2,0),"^",2)="" ; FND+30  ; Message IEN; We didn't load this from Mailman
 . . S $P(^A1AE(11005.1,DA,2,0),"^",3)="" ; FND+31  ; Message date; ditto
 . . D RTNBLD^A1AEM1(DA)                  ; FND+32  ; Load the routine information into 11005 from KIDS message
 . . ; if we load KIDS get rid of HFS "shadow" copy of the KIDS
 . . I $D(^A1AE(11005.5,DA,0)) N DIK S DIK="^A1AE(11005.5," D ^DIK ; FND+34
 ;
 ; Assertions
 N HASRTN S HASRTN=0 ; Has Routines?
 N I F I=1:1 Q:'$D(TXTINFO("CAT",I))  I TXTINFO("CAT",I)="Routine" S HASRTN=1  ; oh yes it does
 I HASRTN,'KIDMISSING D ASSERT($O(^A1AE(11005,DA,"P",0)),"Patch says routine must be present") ; Routine information in Patch
 I 'KIDMISSING D ASSERT($O(^A1AE(11005.1,DA,2,0)),"11005.1 entry must exist for each loaded patch")
 ;
 ; Now, complete and verify the patch, but don't run the input transforms b/c they send mail messages
 ; NB: B/c of the Daisy chain triggers, the current DUZ and date will be used for users. 
 ; NB (cont): I will fix this in a sec.
 N N F N="COM","VER" D
 . N DUZ
 . N NAME S NAME=TXTINFO(N)
 . D STDNAME^XLFNAME(.NAME) ; Remove funny stuff (like dots at the end)
 . S DUZ=$$FIND1^DIC(200,"","QX",NAME,"B") ; Get developer
 . D ASSERT(DUZ,"User "_NAME_" couldn't be resolved")
 . N FDA,DIERR
 . I N="COM" S FDA(11005,IENS,8)="c" D FILE^DIE("",$NA(FDA)) I $D(DIERR) S $EC=",U-FILEMAN-ERROR,"
 . I N="VER" S FDA(11005,IENS,8)="v" D FILE^DIE("",$NA(FDA)) I $D(DIERR) S $EC=",U-FILEMAN-ERROR,"
 . N X,Y S X=TXTINFO(N,"DATE") D ^%DT
 . N FDA,DIERR
 . S FDA(11005,IENS,$S(N="COM":10,1:11))=Y ; 10=DATE PATCH COMPLETED; 11=DATE PATCH VERIFIED
 . D FILE^DIE("",$NA(FDA)) I $D(DIERR) S $EC=",U-FILEMAN-ERROR,"
 ;
 ; Now, put the patches into a review status
 N FDA,DIERR S FDA(11005,IENS,8)="2r" D FILE^DIE("",$NA(FDA)) I $D(DIERR) S $EC=",U-FILEMAN-ERROR,"
 ;
 ; Now keep associated patches for later filing in a holding area
 ; No locks necessary since no increments used.
 N XTMPS S XTMPS=$T(+0)_"-ASSOCIATED-PATCHES"        ; Namespaced Sub in ^XTMP
 N START S START=$$NOW^XLFDT()                       ; Now
 N PURGDT S PURGDT=$$FMADD^XLFDT(START,365.24*2+1\1) ; Hold for two years
 S ^XTMP(XTMPS,0)=PURGDT_U_START_U_"Associated Patches Holding Area"
 N I F I=1:1 Q:'$D(TXTINFO("PREREQ",I))  S ^XTMP(XTMPS,DESIGNATION,TXTINFO("PREREQ",I))=""
 ;
 ;
 ; Sequence number (only for VA patches and real patches not package releases)
 N FDA,DIERR
 I STREAM=1,$P(DESIGNATION,"*",3)'=0 S FDA(11005,IENS,"SEQUENTIAL RELEASE NUMBER")=TXTINFO("SEQ") ; Only file for VA patches
 D:$D(FDA) FILE^DIE("E",$NA(FDA)) I $D(DIERR) S $EC=",U-FILEMAN-ERROR,"
 ;
 LOCK -^A1AE(11005,DA)
 QUIT DA
 ;
ASSERT(X,Y) ; Assertion engine
 ; ZEXCEPT: XTMUNIT - Newed on a lower level of the stack if using M-Unit
 ; I X="" BREAK
 I $D(XTMUNIT) D CHKTF^XTMUNIT(X,$G(Y)) QUIT  ; if we are inside M-Unit, assert using that engine.
 I 'X D EN^DDIOL($G(Y)) S $EC=",U-ASSERTION-ERROR,"  ; otherwise, throw error if assertion fails.
 QUIT
