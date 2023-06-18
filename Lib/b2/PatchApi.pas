////////////////////////////////////////////////////////////////////////////////////////////////////////////
// library patcher_x86.dll
// spread freely (free of charge)
// copyright: Barinov Alexander (baratorch), e-mail: baratorch@yandex.ru
// the form of implementation of low-level hooks (LoHook) is partly borrowed from Berserker (from ERA)
////////////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
// DESCRIPTION.
//
//! The library provides:
//   - convenient unified centralized
//     tools for installing patches and hooks
//     in the code of the target program.
//   - additional tools: disassembler of the lengths of the opcodes and the function
//     copy code with correct transfer of opcodes jmp and call c
//     relative addressing
//! Library allows
//  - set both simple and complex patches.
//    It is almost as convenient to work with methods for installing complex patches
//    as with an assembler (so far only tags and jumps to tags are missing)
//  - set high-level hooks, replacing the original functions in
//    in the target code for their own, without worrying about the registers of the processor,
//    stack, and return to the original code.
//  - install high-level hooks one on another
//    not excluding and adding functionality of hooks
//    set before the last
//  - install low-level hooks with high-level access to
//    the registers of the processor, the stack, the erased code and the return address in the code
//  - cancel any patch and hook installed with this library.
//  - find out whether a particular mode is being used that uses the library
//  - find out which mod (using the library) installed a specific patch / hook
//  - get full access to all patches / hooks installed from other mods
//    using this library
//  - easily and quickly detect conflicting patches from different mods
//    (using this library) 1) marking the log such conflicts as:
//                            - patches / hooks of different size are set to the same address
//                            - install patches / hooks overlapping each other with offset
//                            - patches are installed on top of the hooks and vice versa
//    as well as 2) giving the opportunity to look at the dump (common listing) of all patches
//    and hooks installed using this library at a particular time.
////////////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
// LOGGING.
//
// by default in patcher_x86.dll the logging is disabled to enable it,
// you must create the patcher_x86.ini file in the same folder with the only
// write: Logging = 1 (Logging = 0 - disables logging again)
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
// RULES OF USE.
//
// 1) each mod should call the GetPatcher () function 1 time, saving the result
//    for example: var _P: TPatcher; _P := GetPatcher();
// 2) then using the Patcher.CreateInstance method, you need to create
//    instance of PatcherInstance with its unique name
//    for example: var _PI: TPatcherInstance; _PI := _P.CreateInstance("MyMod");
// 3) then use the methods of classes Patcher and PatcherInstance
//    directly to work with patches and hooks
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////

unit PatchApi;

interface

uses Legacy;

const

// values returned by a LoHook hook function
  EXEC_DEFAULT    = true;
  NO_EXEC_DEFAULT = false;


// values returned by Patch.GetType()
  PATCH_  = 0;
  LOHOOK_ = 1;
  HIHOOK_ = 2;

// values passed as the hooktype argument in PatcherInstance.WriteHiHook and PatcherInstance.CreateHiHook
  CALL_   = 0;
  SPLICE_ = 1;
  FUNCPTR_= 2;

// values passed as the subtype argument in PatcherInstance.WriteHiHook and PatcherInstance.CreateHiHook
  DIRECT_  = 0;
  EXTENDED_= 1;
  SAFE_    = 2;

// values passed as a calltype argument to PatcherInstance.WriteHiHook and PatcherInstance.CreateHiHook
  ANY_     = 0;
  STDCALL_ = 0;
  THISCALL_= 1;
  FASTCALL_= 2;
  CDECL_   = 3;

  FASTCALL_1 = 1;

  NULL_PTR = nil;

type
  _dword_ = cardinal;

// all addresses and part of the pointers are defined by this type,
// if it's more convenient for you, you can replace _ptr_ with any other type, void * or int, for example
  _ptr_ = pointer;

// HookContext structure
// used in functions of LoHook hook
  THookContext = packed record
    eax: integer;
    ecx: integer;
	  edx: integer;
	  ebx: integer;
	  esp: integer;
	  ebp: integer;
	  esi: integer;
	  edi: integer;
 	  RetAddr: _ptr_;
  end;
  PHookContext = ^THookContext;

// Abstract class Patch
// you can create an instance with
// using the methods of class PatcherInstance
  TPatch = packed class

	// returns the address on which to install the patch
    function GetAddress: integer; virtual; stdcall; abstract;

	// returns the size of the patch
    function GetSize: cardinal; virtual; stdcall; abstract;

	// returns the unique name of the PatcherInstance instance with which the patch was created
    function GetOwner: myPChar; virtual; stdcall; abstract;

	// returns the type of the patch
  // for not hook always PATCH_
  // for LoHook always LOHOOK_
  // for HiHook always HIHOOK_
    function GetType: integer; virtual; stdcall; abstract;

	// returns true if the patch is applied and false, if not.
    function IsApplied: boolean; virtual; stdcall; abstract;


  // Apply the patch
  // returns> = 0 if the patch / hook is applied successfully
  // (the return value is the sequence number of the patch in the sequence
  // patches applied around the given address, the larger the number,
  // the later the patch was applied)
  // returns -2 if the patch is already applied
  // The result of executing the method is commonly written to the log
    function Apply: boolean; virtual; stdcall; abstract;

  // ApplyInsert applies a patch specifying the sequence number in the
  // sequences of patches applied to this address.
  // the return values ??are the same as in Patch.Apply
  // the ApplyInsert function, you can pass an argument to the value returned
  // Undo function to apply the patch to the same place it was before the cancel.
    function ApplyInsert(ZOrder: integer): boolean; virtual; stdcall; abstract;

	/////////////////////////////////////////////////////////////////////////////////////////////////////
  // Undo method
  // Undo the patch (hook) (in case the patch is applied last - restores the erased code)
  // Returns the number> = 0 if the patch (hook) was canceled successfully
  // (the return value is the patch number in the sequence
  // patches applied to this address, the larger the number,
  // the later the patch was applied)
  // Returns -2 if the patch has already been canceled (not applied)
  // The result of executing the method is commonly written to the log
    function Undo: integer; virtual; stdcall; abstract;

	/////////////////////////////////////////////////////////////////////////////////////////////////////
  // Destroy method
  // Destructor
  // Cancels and permanently destroys the patch / hook
  // returns always 1 (for compatibility with earlier versions of the library)
  // The result of the destruction is commonly written to the log
    function _Destroy: integer; virtual; stdcall; abstract;

	/////////////////////////////////////////////////////////////////////////////////////////////////////
  // GetAppliedBefore method
  // returns the patch applied before the data
  // returns NULL if this patch is applied first
    function GetAppliedBefore: TPatch; virtual; stdcall; abstract;

	/////////////////////////////////////////////////////////////////////////////////////////////////////
  // GetAppliedAfter method
  // returns the patch applied after the given
  // returns NULL if this patch is applied last
    function GetAppliedAfter: TPatch; virtual; stdcall; abstract;
  end;

// Abstract class LoHook (inherited from Patch, that is, essentially low-hook is a patch)
// you can create an instance with
// using the methods of class PatcherInstance
  TLoHook = packed class(TPatch)
  end;

// Abstract class HiHook (inherited from Patch, that is, essentially hi-hook is a patch)
// you can create an instance using methods from the class PatcherInstance
  THiHook = packed class(TPatch)

	// returns a pointer to the function (on the bridge to the function in the case of SPLICE_),
	// replaced by a hook
	// Attention! Calling a function for an unused hook, you can get
	// irrelevant (but working) value.
	  function GetDefaultFunc: _ptr_; virtual; stdcall; abstract;

 // returns a pointer to the original function (on the bridge to the function in the case of SPLICE_),
 // replaced by a hook (hooks) at this address
 // (that is, it returns GetDefaultFunc () for the first hook applied to this address)
 // Attention! Calling a function for an unused hook, you can get
 // irrelevant (but working) value.
	  function GetOriginalFunc: _ptr_; virtual; stdcall; abstract;

 // returns the return address to the original code
 // can be used inside the hook function
 // SPLICE_ EXTENDED_ or SAFE_ hook to find out where it came from
 // for SPLICE_ DIRECT_ hook function always returns 0 (ie for DIRECT_ hook possibility to
 // find the return address through it - no)
	  function GetReturnAddress: _ptr_; virtual; stdcall; abstract;
  end;

// Abstract class PatcherInstance
// create / get an instance using the CreateInstance and GetInstance methods of the Patcher class
// directly allows you to create / install patches and hooks in the code,
// adding them to the tree of all the patches / hooks created by the patcher_x86.dll library
  TPatcherInstance = packed class

	////////////////////////////////////////////////////////////
  // WriteByte method
	// write a one-byte number at address
	// (creates and applies DATA_ patch)
	// Returns the pointer to the patch
	  function WriteByte(address: _ptr_; value: integer): TPatch; virtual; stdcall; abstract;

	////////////////////////////////////////////////////////////
  // WriteWord method
  // write a two-byte number at address
  // (creates and applies DATA_ patch)
  // Returns the pointer to the patch
	  function WriteWord(address: _ptr_; value: integer): TPatch; virtual; stdcall; abstract;

	////////////////////////////////////////////////////////////
  // WriteDword method
  // write a four-byte number at address
  // (creates and applies DATA_ patch)
  // Returns the pointer to the patch
	  function WriteDword(address: _ptr_; value: integer): TPatch; virtual; stdcall; abstract;

	////////////////////////////////////////////////////////////
  // WriteJmp method
  // writes jmp to opcode at address
  // (creates and applies a CODE_ patch)
  // Returns the pointer to the patch
  // the patch closes an integer number of opcodes,
  // i.e. The size of the patch> = 5, the difference is filled with NOPs.
	  function WriteJmp(address, to_address: _ptr_): TPatch; virtual; stdcall; abstract;

	////////////////////////////////////////////////////////////
  // WriteHexPatch method
  // writes to the address address the byte sequence,
  // defined hex_str
  // (creates and applies DATA_ patch)
  // Returns the pointer to the patch
  // hex_str - c-string can contain hexadecimal digits
  // 0123456789ABCDEF (uppercase only!) Other characters
  // when reading by the method hex_str ignored (skipped)
  // convenient to use as an argument to this method
  // copied using Binary copy in OllyDbg
  // Example:
  //   Pi->WriteHexPatch(0x57b521, "6A 01 6A 00");
	  function WriteHexPatch(address: _ptr_; hex_cstr: myPChar): TPatch; virtual; stdcall; abstract;

	////////////////////////////////////////////////////////////
  // Method WriteCodePatchVA
  // in the original form, the method is not supposed to be used,
  // see (below) the description of the wrapper method WriteCodePatch
	  function WriteCodePatchVA(address: _ptr_; format: myPChar; va_args: _ptr_): TPatch; virtual; stdcall; abstract;

	////////////////////////////////////////////////////////////
  // Method WriteLoHook
  // creates an address low-level hook (CODE_ patch) and applies it
  // returns pointer to the hook
  // func - function called when the hook triggers
  // must have the form int __stdcall func (LoHook * h, HookContext * c);
  // in HookContext * c are passed for reading / changing
  // processor registers and return address
  // if func returns EXEC_DEFAULT, then
  // after the func is completed, the code is truncated.
  // if - SKIP_DEFAULT - the erased code is not executed
  //
  // ATTENTION!
  // the size of the memory that can be placed on the context stack
  // using c-> esp and c-> Push, is limited to 128 bytes.
  // if you need another restriction, use the WriteLoHookEx or CreateLoHookEx method.
	  function WriteLoHook(address: _ptr_; func: pointer): TLoHook; virtual; stdcall; abstract;

	////////////////////////////////////////////////////////////
	// Method WriteHiHook
  // creates a high-level hook at address and applies it
  // returns pointer to the hook
  //
  // new_func - function replacing the original
  //
  // hooktype - hook type:
  // CALL_ - hook to the function call at address
  // the E8 and FF 15 opcodes are supported, otherwise the hook is not installed
  // and the information about this error is written to the log
  // SPLICE_ - hook directly to the FUNCTION itself at address
  // FUNCPTR_ - hook to the function in the pointer (rarely used, mostly for hooks in import tables)
  //
  // subtype - the subtype of the hook:
  // DIRECT_ - new_func has the same form as
  // original replaceable function
  // note: instead of __thiscall f (this)
  // you can use __fastcal f (this_)
  // instead of __thiscall f (this, ...) you can use
  // __fastcall f (this_, no_used_edx, ...)
  // EXTENDED_ - new_func function is passed the first stack argument
  // pointer to the HiHook instance and, in the case
  // conventions of the original __thiscall and __fastcall
  // register arguments are passed by stack second
  // So the function new_func should look like
  //? __stdcall new_func (HiHook * hook,?) For? ? Orig (?)
  //
  // ATTENTION! EXTENDED_ FASTCALL_ supports only functions with 2 or more arguments
  // for __fastcall with 1 argument, use EXTENDED_ FASTCALL_1 / EXTENDED_ THISCALL_
  //
  // SAFE_ is the same as EXTENDED_, but before calling (at the time of the call) GetDefaultFunc () is restored
  // The register values of the EAX, ECX(if not FASTCALL_ and not THISCALL_)
  // EDX (if not FASTCALL_), EBX, ESI, EDI, which were at the time of the call of the replaced function
  //
  //  In the vast majority of cases it is more convenient to use EXTENDED
  //  But DIRECT_ is executed faster because there is no bridge to the new replacement function
  //
  // Calltype - an agreement to call the original replacement f-tion:
  //  STDCALL_
  //  THISCALL_
  //  FASTCALL_
  //  CDECL_
  // need to specify the agreement correctly in order to EXTENDED_ hook correctly
  // built a bridge to a new replacement function
  //
  // CALL_, SPLICE_ hook is the CODE_ patch
  // FUNCPTR_ hook is a DATA_ patch
  //
	  function WriteHiHook(address: _ptr_; hooktype, subtype, calltype: integer; new_func: pointer): THiHook; virtual; stdcall; abstract;

	///////////////////////////////////////////////////////////////////
  // Methods Create ...
  // create a patch / hook as well as the corresponding Write ... methods,
  // but do not use it
  // return pointer to patch / hook
	  function CreateBytePatch(address: _ptr_; value: integer): TPatch; virtual; stdcall; abstract;
	  function CreateWordPatch(address: _ptr_; value: integer): TPatch; virtual; stdcall; abstract;
	  function CreateDwordPatch(address: _ptr_; value: integer): TPatch; virtual; stdcall; abstract;
	  function CreateJmpPatch(address, to_address: _ptr_): TPatch; virtual; stdcall; abstract;
	  function CreateHexPatch(address: _ptr_; hex_str: myPChar): TPatch; virtual; stdcall; abstract;
	  function CreateCodePatchVA(address: _ptr_; format: myPChar; va_args: _ptr_): TPatch; virtual; stdcall; abstract;
	  function CreateLoHook(address: _ptr_; func: pointer): TLoHook; virtual; stdcall; abstract;
	  function CreateHiHook(address: _ptr_; hooktype, subtype, calltype: integer; new_func: pointer): THiHook; virtual; stdcall; abstract;

	////////////////////////////////////////////////////////////
  // ApplyAll method
  // applies all patches / hooks created by this instance of PatcherInstance
  // always returns 1 (for compatibility with earlier versions of the library)
  // (see Patch.Apply)
	  function ApplyAll: boolean; virtual; stdcall; abstract;

	////////////////////////////////////////////////////////////
  // UndoAll Method
  // cancels all patches / hooks created by this instance of PatcherInstance
  // i.e. For each of the patches / hooks calls the Undo method
  // always returns 1 (for compatibility with earlier versions of the library)
  // (see Patch.Undo)
	  function UndoAll: boolean; virtual; stdcall; abstract;

	////////////////////////////////////////////////////////////
  // DestroyAll Method
  // cancels and permanently destroys all patches / hooks created by this instance of PatcherInstance
  // i.e. For each of the patches / hooks calls the Destroy method
  // always returns 1 (for compatibility with earlier versions of the library)
  // (see Patch.Destroy)
	  function DestroyAll: boolean; virtual; stdcall; abstract;

	// in the original form, the method is not supposed to be used,
  // see (below) the description of the wrapper method WriteDataPatch
	  function WriteDataPatchVA(address: _ptr_; format: myPChar; va_args: _ptr_): TPatch; virtual; stdcall; abstract;

  // in the original form, the method is not supposed to be used,
  // see (below) the description of the wrapper method WriteDataPatch
	  function CreateDataPatchVA(address: _ptr_; format: myPChar; va_args: _ptr_): TPatch; virtual; stdcall; abstract;

  // GetLastPatchAt method
  // returns NULL if no patch / hook has been applied in the vicinity of the address address,
  // created by this instance of PatcherInstance
  // otherwise returns the last applied patch / hook in the neighborhood of the address address,
  // created by this instance of PatcherInstance
   	function GetLastPatchAt(address: _ptr_): TPatch; virtual; stdcall; abstract;

  // UndoAllAt Method
  // cancels the patches applied by this instance of PatcherInstance
  // in the neighborhood of address
  // always returns 1 (for compatibility with earlier versions of the library)
  // (see Patch.Undo)
   	function UndoAllAt(address: _ptr_): boolean; virtual; stdcall; abstract;

  // GetFirstPatchAt method
  // returns NULL if no patch / hook has been applied in the vicinity of the address address,
  // created by this instance of PatcherInstance
  // otherwise returns the first applied patch / hook in the neighborhood of the address address,
  // created by this instance of PatcherInstance
    function GetFirstPatchAt(address: _ptr_): TPatch; virtual; stdcall; abstract;



  // Write Method
  // writes address data / code from memory to address data size size bytes
  // if is_code = 1, then a CODE_ patch is created and written, if 0 is a DATA patch.
  // Returns the pointer to the patch
	  function Write(address: _ptr_; data: _ptr_; size: _dword_; is_code: boolean): TPatch; virtual; stdcall; abstract;

  // CreatePatch method
  // creates a patch as well as the Write method,
  // but does not apply it
  // return pointer to patch
	  function CreatePatch(address: _ptr_; data: _ptr_; size: _dword_; is_code: boolean): TPatch; virtual; stdcall; abstract;


	////////////////////////////////////////////////////////////
  // Method WriteCodePatch
  // writes to the address address the byte sequence,
  // defined format and ...
  // (creates and applies a CODE_ patch)
  // Returns the pointer to the patch
  // format - c-string can contain hexadecimal digits
  // 0123456789ABCDEF (uppercase only!),
  // as well as special format-characters (lower case!):
  //% b - (byte) writes a single-byte number from ...
  //% w - (word) writes a two-byte number from ...
  //% d - (dword) writes a four-byte number from ...
  //% j - writes jmp to the address from ...
  //% c - writes ?all ...
  //% m - copies the code to the address ... the size ... (ie reads 2 arguments from ...)
  // copying occurs via MemCopyCodeEx (see description)
  // %% - writes a string with format characters from ...
  //% o - (offset) places the address offset in the argument from the argument
  // Complex code, relative to the beginning of the Complex code.
  //% n - write nop opcode, number equal to ... \
  // # 0: - # 9: -set the label (from 0 to 9) to which you can go with # 0 - # 9 \
  // # 0 - # 9-write the address after the opcodes EB, 70 - 7F, E8, E9, 0F80 - 0F8F
  // corresponding label; After other opcodes nothing writes
  // ~ b - takes from ... the absolute address and writes the relative offset before it
  // 1 byte in size (used for EB, 70 - 7F opcodes)
  // ~ d - takes from ... the absolute address and writes the relative offset before it
  // 4 bytes in size (used for the E8, E9, 0F 80 - 0F 8F opcodes)
  //%. - does nothing (like any other character not declared above after%)
  // abstract example:
  // Patch * p = pi-> WriteCodePatch (address,
  // "# 0: %%",
  // "B9% d %%", this, // mov ecx, this //
  // "BA% d %%", this-> context, // mov edx, context //
  // "% c %%", func, // call func //
  // "83 F8 01 %%", // cmp eax, 1
  // "0F 85 # 7 %%", // jne long to label 7 (if func returns 0)
  // "83 F8 02 %%", // cmp eax, 2
  // "0F 85 ~ d %%", 0x445544, // jne long to 0x445544 (if func returns 0)
  // "EB # 0 %%", // jmp short to label 0
  // "% m %%", address2, size, // exec code copy from address2
  // "# 7: FF 25% d%.", & Return_address); // jmp [& return_address]
   	function WriteCodePatch(address: _ptr_; const args: array of const): TPatch; stdcall;

	////////////////////////////////////////////////////////////
  // The CreateCodePatch method
  // creates a patch as well as the WriteCodePatch method,
  // but does not apply it
  // returns pointer to patch
   	function CreateCodePatch(address: _ptr_; const args: array of const): TPatch; stdcall;

	////////////////////////////////////////////////////////////
  // Method WriteDataPatch
  // writes to the address address the byte sequence,
  // defined format and ...
  // (creates and applies DATA_ patch)
  // Returns the pointer to the patch
  // format - a c-string can contain hexadecimal digits
  // 0123456789ABCDEF (uppercase only!),
  // as well as special format-characters (lower case!):
  //% b - (byte) writes a single-byte number from ...
  //% w - (word) writes a two-byte number from ...
  //% d - (dword) writes a four-byte number from ...
  //% m - copies data to an address ... size ... (ie reads 2 arguments from ...)
  // %% - writes a string with format characters from ...
  //% o - (offset) places the address offset in the argument from the argument
  // Complex code, relative to the beginning of the Complex code.
  //%. - does nothing (like any other character not declared above after%)
  // abstract example:
  // Patch * p = pi-> WriteDataPatch (address,
  // "FF FF FF% d %%", var,
  // "% m %%", address2, size,
  // "AE%.");
   	function WriteDataPatch(address: _ptr_; const args: array of const): TPatch; stdcall;

	////////////////////////////////////////////////////////////
  // CreateDataPatch method
  // creates the patch as well as the WriteDataPatch method,
  // but does not apply it
  // returns pointer to patch
   	function CreateDataPatch(address: _ptr_; const args: array of const): TPatch; stdcall;

  end;

  // type "variable" is used for TPatcher.VarInit methods returned
  // and TPatcher.VarFind values
  TVariable = packed class
    // returns the value of "variable" (thread-safe access)
    function GetValue: _dword_; virtual; stdcall; abstract;

    // sets the value of a "variable" (thread safe access)
    procedure SetValue(value: _dword_); virtual; stdcall; abstract;

    // returns a pointer to the "variable" value (accessing the "variable" value through a pointer is not thread safe)
    function GetPValue: Pointer; virtual; stdcall; abstract;
  end;

  // class Patcher
  TPatcher = packed class

	// TPatcher class

	///////////////////////////////////////////////////
  // CreateInstance method
  // Creates an instance of the PatcherInstance class, which
  // directly allows you to create patches and hooks and
  // returns a pointer to this instance.
  // owner - the unique name of the PatcherInstance instance
  // the method returns NULL if an instance with the name owner is already created
  // if owner = NULL or owner = '' then
  // the PatcherInstance instance will be created with the module name from
  // the function was called.
   	function CreateInstance(owner_name: myPChar): TPatcherInstance; virtual; stdcall; abstract;

	///////////////////////////////////////////////////
  // GetInstance method
  // Returns a pointer to an instance of PatcherInstance
  // with the name owner.
  // the method returns NULL if
  // the instance named owner does not exist (was not created)
  // the module name can be passed as an argument.
  // Is used for :
  // - check if some mod is active, using patcher_x86.dll
  // - get access to all patches and hooks of some mod,
  // using patcher_x86.dll
   	function GetInstance(owner_name: myPChar): TPatcherInstance; virtual; stdcall; abstract;

	///////////////////////////////////////////////////
  // GetLastPatchAt method
  // returns NULL if no patch / hook is applied in the vicinity of the address address
  // otherwise returns the last applied patch / hook in the neighborhood of address
  // consistently walk through all the patches in a given neighborhood
  // using this method and Patch.GetAppliedBefore
   	function GetLastPatchAt(address: _ptr_): TPatch; virtual; stdcall; abstract;

	///////////////////////////////////////////////////
  // UndoAllAt Method
  // cancels all patches / hooks at address
  // returns FALSE if at least 1 patch / hook failed to undo (see Patch.Undo)
  // otherwise returns TRUE
  	function UndoAllAt(address: _ptr_): boolean; virtual; stdcall; abstract;

	///////////////////////////////////////////////////
  // SaveDump method
  // saves to a file named file_name
  // - the number and names of all TPatcherInstance instances
  // - the number of all applied patches / hooks
  // - list of all applied patches and hooks
	  procedure SaveDump(file_name: myPChar); virtual; stdcall; abstract;

	///////////////////////////////////////////////////
  // SaveLog method
  // saves the log to a file named file_name
	  procedure SaveLog(file_name: myPChar); virtual; stdcall; abstract;

	///////////////////////////////////////////////////
  // GetMaxPatchSize Method
  // The patcher_x86.dll library imposes some restrictions
  // to the maximum size of the patch,
  // which one can be recognized using the GetMaxPatchSize method
  // (at the moment this is 262144 bytes, i.e., dohrena :))
   	function GetMaxPatchSize: integer; virtual; stdcall; abstract;

	// additional methods:

	///////////////////////////////////////////////////
  // Method WriteComplexDataVA
  // in the original form, the method is not supposed to be used,
  // see (below) the description of the wrapper method WriteComplexString
   	function WriteComplexDataVA(address: _ptr_; format: myPChar; va_args: _ptr_): integer; virtual; stdcall; abstract;

	///////////////////////////////////////////////////
  // method GetOpcodeLength
  // so-called. Disassembler of the lengths of the opcodes
  // returns the length in bytes of the opcode at p_opcode
  // returns 0 if opcode is unknown
   	function GetOpcodeLength(p_opcode: pointer): integer; virtual; stdcall; abstract;

	///////////////////////////////////////////////////
  // method MemCopyCode
  // copies the code from memory to src address in memory at dst
  // MemCopyCode always copies an integer number of opcodes with the size> = size. Be careful!
  // returns the size of the copied code.
  // differs by the action from a simple copy of the memory,
  // that correctly copies the ops E8 (call), E9 (jmp long), 0F80 - 0F8F (j ** long)
  // c relative addressing without knocking down addresses in them, if instructions
  // Forward outside the copied blocking.
    procedure MemCopyCode(dst, src: pointer; size: cardinal); virtual; stdcall; abstract;


	///////////////////////////////////////////////////
  // GetFirstPatchAt method
  // returns NULL if no patch / hook is applied in the vicinity of the address address
  // otherwise returns the first applied patch / hook in the neighborhood of address
  // consistently walk through all the patches in a given neighborhood
  // using this method and Patch.GetAppliedAfter
    function GetFirstPatchAt(address: _ptr_): TPatch; virtual; stdcall; abstract;

	///////////////////////////////////////////////////
  // method MemCopyCodeEx
  // copies the code from memory to src address in memory at dst
  // returns the size of the copied code.
  // differs from MemCopyCode in that,
  // that correctly copies the opcodes EB (jmp short), 70 - 7F (j ** short)
  // c relative addressing without knocking down addresses in them, if instructions
  // send outside the copied block (in this case they are replaced by
  // corresponding to E9 (jmp long), 0F80 - 0F8F (j ** long) opcodes.
  // Attention! Because of this, the size of the copied code can be significantly
  // more than copied.
    function MemCopyCodeEx(dst, src: pointer; size: cardinal): integer; virtual; stdcall; abstract;

  // VarInit method
  // initializes a "variable" named name and sets its value to value
  // if a variable with the same name already exists, then simply sets its value to value
  // returns a variable on success and nil otherwise
    function VarInit(name: myPChar; value: _dword_): TVariable; virtual; stdcall; abstract;

  // method VarFind
  // returns a variable named name, if one has been initialized
  // if not, returns nil
    function VarFind(name: myPChar): TVariable; virtual; stdcall; abstract;

	////////////////////////////////////////////////////////////////////
  // method WriteComplexData
  // is a more convenient interface
  // method WriteComplexDataVA
  // this method is defined here and not in the library, because Its appearance
  // differs in C and Delphi
  // The method's functionality is almost the same as that of PatcherInstance.WriteCodePatch
  // (see the description of this method)
  // that is, the method writes to the address address, the sequence of bytes,
  // defined by the arguments format and ...,
  // BUT! DOES NOT create an instance of the Patch class, with all that is implied (i.e., not allowing to undo, access to edit from another mode, etc.)
  // ATTENTION!
  // Use this method only for dynamically creating blocks
  // code, i.e. Write this method only in your memory,
  // a in the code of the program to be modified only with the help of
  // PatcherInstance.WriteCodePatch
   	function WriteComplexData(address: _ptr_; const args: array of const): integer; stdcall;

  end;

// function GetPatcher
// loads the library and, by calling the only exported
// function _GetPatcherX86 @ 0, returns a pointer to the Patcher object,
// through which the entire functionality of the library patcher_x86.dll is available
// return NULL on failure
// function is called 1 time, which is obvious from its definition
  function GetPatcher: TPatcher; stdcall;

// Call function allows you to call an arbitrary function at a specific address.
// It is also used to call functions obtained using THiHook.GetDefaultFunc and THiHook.GetOriginalFunc
  function Call(calltype: integer; address: _ptr_; const args: array of const): _dword_; stdcall;


implementation

uses Windows;

type
  TDwordArgs = array [0..24] of DWORD;

// This function converts array of const to array of _dword_ for functions that take an arbitrary
// number of arguments of different types
  procedure __MoveToDwordArgs(const args: array of const; var dword_args: TDwordArgs);
  var
    i: integer;
  begin
    for i := 0 to High(args) do begin
      with args[i] do begin
        case VType of
          vtInteger:    dword_args[i] := _dword_(VInteger);
          vtBoolean:    dword_args[i] := _dword_(VBoolean);
          vtChar:       dword_args[i] := _dword_(VChar);
          vtPChar:      dword_args[i] := _dword_(myPChar(VPChar));
          vtPointer:    dword_args[i] := _dword_(VPointer);
          vtString:     dword_args[i] := _dword_(myPChar(AnsiString(VString^ + #0)));
          vtAnsiString: dword_args[i] := _dword_(myPChar(VAnsiString));
          vtWideChar:   dword_args[i] := ord(VWideChar);
          vtPWideChar:  dword_args[i] := _dword_(pointer(VPWideChar));
          vtWideString: dword_args[i] := _dword_(VWideString);
          vtObject:     dword_args[i] := _dword_(pointer(VObject));
        else // vtExtended, vtClass, vtCurrency, vtVariant, vtInterface, vtInt64, vtUnicodeString
          MessageBoxA(0, 'Patch Api - __MoveToDwordArgs - Unicod not allowed', '__MoveToDwordArgs', 0);
          asm int 3 end;
        end;
      end;
    end;
  end;

  function CALL_CDECL(address: _ptr_; var dword_args: TDwordArgs; args_count: integer): _dword_;
  var
    r: _dword_;
    d_esp: integer;
    parg: _ptr_;
  begin
    if args_count > 0 then parg := _ptr_(@dword_args[args_count-1]);
    d_esp := args_count * 4;
   asm
      pushad
      mov edi, parg
      mov esi, args_count
   @loop_start:
      cmp esi, 1
      jl @loop_end
      push [edi]
      sub edi, 4
      Dec esi
      jmp @loop_start
   @loop_end:
      mov eax, address
      call eax
      mov r, eax
      add esp, d_esp
      popad
    end;
    result := r;
  end;

  function CALL_STD(address: _ptr_; var dword_args: TDwordArgs; args_count: integer): _dword_;
  var
    r: _dword_;
    parg: _ptr_;
  begin
    if args_count > 0 then parg := _ptr_(@dword_args[args_count-1]);

    asm
      pushad
      mov edi, parg
      mov esi, args_count
    @loop_start:
      cmp esi, 1
      jl @loop_end
      push [edi]
      sub edi, 4
      Dec esi
      jmp @loop_start
    @loop_end:
      mov eax, address
      call eax
      mov r, eax
      popad
    end;

    result := r;
  end;

  function CALL_THIS(address: _ptr_; var dword_args: TDwordArgs; args_count: integer): _dword_;
  var
    r, ecx_arg: _dword_;
    stack_args_count: integer;
    parg: _ptr_;
  begin
    stack_args_count := args_count - 1;

    if args_count > 0 then begin
      ecx_arg := dword_args[0];
      parg := _ptr_(@dword_args[args_count-1]);
    end
    else begin
      asm int 3 end;
    end;

    asm
      pushad
      mov edi, parg
      mov esi, stack_args_count
    @loop_start:
      cmp esi, 1
      jl @loop_end
      push [edi]
      sub edi, 4
      Dec esi
      jmp @loop_start
    @loop_end:
      mov ecx, ecx_arg
      mov eax, address
      call eax
      mov r, eax
      popad
    end;

    result := r;
  end;

  function CALL_FAST(address: _ptr_; var dword_args: TDwordArgs; args_count: integer): _dword_;
  var
    r, ecx_arg, edx_arg: _dword_;
    stack_args_count: integer;
    parg: _ptr_;
  begin
    stack_args_count := args_count - 2;

    if args_count > 1 then begin
      ecx_arg := dword_args[0];
      edx_arg := dword_args[1];
      parg := _ptr_(@dword_args[args_count-1]);
    end
    else begin
      result := CALL_THIS(address, dword_args, args_count);
      exit;
    end;

    asm
      pushad
      mov edi, parg
      mov esi, stack_args_count
    @loop_start:
      cmp esi, 1
      jl @loop_end
      push [edi]
      sub edi, 4
      Dec esi
      jmp @loop_start
    @loop_end:
      mov ecx, ecx_arg
      mov edx, edx_arg
      mov eax, address
      call eax
      mov r, eax
      popad
    end;

    result := r;
  end;

  function Call(calltype: integer; address: _ptr_; const args: array of const): _dword_;
  var
    dword_args: TDwordArgs; 
  
  begin
    __MoveToDWordArgs(args, dword_args);
    
    case calltype of
      CDECL_   : result := CALL_CDECL(address, dword_args, Length(args));
      STDCALL_ : result := CALL_STD(address, dword_args, Length(args));
      THISCALL_: result := CALL_THIS(address, dword_args, Length(args));
      FASTCALL_: result := CALL_FAST(address, dword_args, Length(args));
    else
      result := 0;
      asm int 3 end;
    end;
  end;


  function TPatcherInstance.WriteCodePatch(address: _ptr_; const args: array of const): TPatch;
  var
    dword_args: TDwordArgs;
  
  begin
    __MoveToDwordArgs(args, dword_args);
    result := WriteCodePatchVA(address, myPChar(dword_args[0]), _ptr_(@dword_args[1]));
  end;

  function TPatcherInstance.CreateCodePatch(address: _ptr_; const args: array of const): TPatch;
  var
    dword_args: TDwordArgs;
  
  begin
    __MoveToDwordArgs(args, dword_args);
    result := CreateCodePatchVA(address, myPChar(dword_args[0]), _ptr_(@dword_args[1]));
  end;


  function TPatcherInstance.WriteDataPatch(address: _ptr_; const args: array of const): TPatch;
  var
    dword_args: TDwordArgs;

  begin
    __MoveToDwordArgs(args, dword_args);
    result := WriteDataPatchVA(address, myPChar(dword_args[0]), _ptr_(@dword_args[1]));
  end;

  function TPatcherInstance.CreateDataPatch(address: _ptr_; const args: array of const): TPatch;
  var
    dword_args: TDwordArgs;
  
  begin
    __MoveToDwordArgs(args, dword_args);
    result := CreateDataPatchVA(address, myPChar(dword_args[0]), _ptr_(@dword_args[1]));
  end;


  function TPatcher.WriteComplexData(address: _ptr_; const args: array of const): integer;
  var
    dword_args: TDwordArgs;
  
  begin
    __MoveToDwordArgs(args, dword_args);
    result := WriteComplexDataVA(address, myPChar(dword_args[0]), _ptr_(@dword_args[1]));
  end;

  var
    PatcherPtr: TPatcher = nil;
  
  function GetPatcher: TPatcher;
  var
    dll: cardinal;
    func: _ptr_;
  begin
    result := PatcherPtr;
  
    if result = nil then begin
      dll := Windows.LoadLibraryA('patcher_x86.dll');
      {!} Assert(dll <> 0);
      func := _ptr_(Windows.GetProcAddress(dll, myPChar('_GetPatcherX86@0')));
      {!} Assert(func <> NULL_PTR);
      result := TPatcher(Call(STDCALL_, func, []));
      {!} Assert(result <> nil);
    end;
  end;

end.
