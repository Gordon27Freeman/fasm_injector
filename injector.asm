format PE GUI 4.0
entry start

include 'win32a.inc'

struct PROCESSENTRY32
       dwSize                   dd ?
       cntUsage                 dd ?
       th32ProcessID            dd ?
       th32DefaultHeapID        dd ?
       th32ModuleID             dd ?
       cntThreads               dd ?
       th32ParentProcessID      dd ?
       pcPriClassBase           dd ?
       dwFlags                  dd ?
       szExeFile                db 260 dup (?)
ends

struct OPENFILENAMEA
       lStructSize              dd ?
       hwndOwner                dd ?
       hInstance                dd ?
       lpstrFilter              dd ?
       lpstrCustomFilter        dd ?
       nMaxCustFilter           dd ?
       nFilterIndex             dd ?
       lpstrFile                dd ?
       nMaxFile                 dd ?
       lpstrFileTitle           dd ?
       nMaxFileTitle            dd ?
       lpstrInitialDir          dd ?
       lpstrTitle               dd ?
       Flags                    dd ?
       nFileOffset              dw ?
       nFileExtension           dw ?
       lpstrDefExt              dd ?
       lCustData                dd ?
       lpfnHook                 dd ?
       lpTemplateName           dd ?
ends

TH32CS_SNAPPROCESS equ 000002h
OFN_PATHMUSTEXIST  equ 000800h
OFN_FILEMUSTEXIST  equ 001000h

section '.text' code readable executable

  start:
        invoke  GetModuleHandle, 0
        mov     [instance], eax

        invoke  memset, ofn, 0, sizeof.OPENFILENAMEA

        invoke  malloc, 520
        mov     dword [process], eax
        add     eax, 260
        mov     dword [filename], eax

        mov     dword [ofn.lStructSize], sizeof.OPENFILENAMEA
        mov     dword [ofn.hwndOwner], HWND_DESKTOP
        mov     dword [ofn.lpstrFile], eax
        mov     dword [ofn.nMaxFile], 260
        mov     dword [ofn.lpstrFilter], filter
        mov     dword [ofn.nFilterIndex], 1
        mov     dword [ofn.Flags], OFN_PATHMUSTEXIST + OFN_FILEMUSTEXIST
        mov     dword [entry32.dwSize], sizeof.PROCESSENTRY32

        invoke  DialogBoxParam, [instance], 0, HWND_DESKTOP, DialogProc, 0
        invoke  ExitProcess, 0

  proc DialogProc hwndDlg, uMsg, wParam, lParam
        push    ebx esi edi

        cmp     [uMsg], WM_INITDIALOG
        je      .initdialog
        cmp     [uMsg], WM_COMMAND
        je      .command
        cmp     [uMsg], WM_CLOSE
        je      .close

        xor     eax, eax
        jmp     .finish

  .initdialog:
        invoke  LoadImage, [instance], 5, IMAGE_ICON, 16, 16, 0
        invoke  SendMessage, [hwndDlg], WM_SETICON, ICON_SMALL, eax
        invoke  GetDlgItem, [hwndDlg], 3
        mov     dword [combobox], eax
        jmp     .refresh

  .command:
        cmp     [wParam], BN_CLICKED shl 16 + 0
        je      .inject
        cmp     [wParam], BN_CLICKED shl 16 + 1
        je      .refresh
        cmp     [wParam], BN_CLICKED shl 16 + 2
        je      .choose
        jmp     .processed

  .inject:
        invoke  SendMessage, [combobox], CB_GETCURSEL, 0, 0
        mov     dword [cursel], eax

        invoke  SendMessage, [combobox], CB_GETLBTEXT, [cursel], [process]
        mov     eax, dword [process]
        cmp     dword [eax], 0
        je      .processed

        invoke  CreateToolhelp32Snapshot, TH32CS_SNAPPROCESS, 0
        mov     dword [snapshot], eax

        invoke  Process32First, [snapshot], entry32
        cmp     eax, 0
        je      .inject_end

  .inject_next:
        invoke  Process32Next, [snapshot], entry32
        cmp     eax, 0
        je      .inject_end

        invoke  strcmp, [process], entry32.szExeFile
        cmp     eax, 0
        je      .inject_end

        jmp     .inject_next

  .inject_end:
        invoke  OpenProcess, PROCESS_ALL_ACCESS, 0, [entry32.th32ProcessID]
        mov     dword [handle], eax

        invoke  VirtualAllocEx, [handle], 0, 260, MEM_RESERVE + MEM_COMMIT, PAGE_EXECUTE_READWRITE
        mov     dword [address], eax

        invoke  WriteProcessMemory, [handle], eax, [filename], 260, 0
        invoke  GetModuleHandle, kernel32
        invoke  GetProcAddress, eax, loadlibrary
        invoke  CreateRemoteThread, [handle], 0, 0, eax, [address], 0, 0

        invoke  CloseHandle, [handle]
        invoke  CloseHandle, [snapshot]
        
  .close:
        invoke  EndDialog, [hwndDlg], 0

  .refresh:
        invoke  SendMessage, [combobox], CB_RESETCONTENT, 0, 0

        invoke  CreateToolhelp32Snapshot, TH32CS_SNAPPROCESS, 0
        mov     dword [snapshot], eax

        invoke  Process32First, [snapshot], entry32
        cmp     eax, 0
        je      .refresh_end

  .refresh_next:
        invoke  Process32Next, [snapshot], entry32
        cmp     eax, 0
        je      .refresh_end

        invoke  SendMessage, [combobox], CB_ADDSTRING, 0, entry32.szExeFile
        jmp     .refresh_next

  .refresh_end:
        invoke  CloseHandle, [snapshot]
        jmp     .processed

  .choose:
        invoke  GetOpenFileName, ofn
        cmp     eax, 0
        je      .processed

        invoke  SetDlgItemText, [hwndDlg], 4, [filename]

  .processed:
        mov     eax, 1
  .finish:
        pop     edi esi ebx
        ret
  endp

section '.data' data readable writeable

  instance dd 0
  cursel dd 0
  combobox dd 0
  snapshot dd 0
  handle dd 0
  address dd 0
  filename dd 0
  process dd 0

  entry32 PROCESSENTRY32
  ofn OPENFILENAMEA

  kernel32 db 'kernel32.dll', 0
  loadlibrary db 'LoadLibraryA', 0
  filter db '*.DLL', 0, '*.DLL', 0

section '.idata' import data readable

  library kernel, 'KERNEL32.DLL',\
          user, 'USER32.DLL',\
          comdlg, 'COMDLG32.DLL',\
          msvcrt, 'MSVCRT.DLL'

  import kernel,\
         GetModuleHandle,'GetModuleHandleA',\
         CreateToolhelp32Snapshot, 'CreateToolhelp32Snapshot',\
         Process32First, 'Process32First',\
         Process32Next, 'Process32Next',\
         OpenProcess, 'OpenProcess',\
         VirtualAllocEx, 'VirtualAllocEx',\
         WriteProcessMemory, 'WriteProcessMemory',\
         GetProcAddress, 'GetProcAddress',\
         CreateRemoteThread, 'CreateRemoteThread',\
         CloseHandle, 'CloseHandle',\
         ExitProcess,'ExitProcess'

  import user,\
         LoadImage, 'LoadImageA',\
         DialogBoxParam,'DialogBoxParamA',\
         GetDlgItem, 'GetDlgItem',\
         SetDlgItemText, 'SetDlgItemTextA',\
         SendMessage, 'SendMessageA',\
         EndDialog,'EndDialog'

  import comdlg,\
         GetOpenFileName, 'GetOpenFileNameA'

  import msvcrt,\
         strcmp, 'strcmp',\
         malloc, 'malloc',\
         memset, 'memset'

section '.rsrc' resource data readable

  directory RT_DIALOG, dialogs,\
            RT_ICON, icons,\
            RT_GROUP_ICON, group_icons

  resource icons,\
           1, LANG_NEUTRAL, icon_data

  resource group_icons,\
           5, LANG_NEUTRAL, main_icon

  resource dialogs,\
           0, LANG_ENGLISH + SUBLANG_DEFAULT, injector

  icon main_icon, icon_data, 'injector.ico'

  dialog injector, 'Injector', 50, 50, 249, 63, WS_OVERLAPPED + WS_CAPTION + WS_SYSMENU + WS_MINIMIZEBOX
         dialogitem 'STATIC', 'Process:', -1, 5, 7, 70, 8, WS_VISIBLE
         dialogitem 'STATIC', 'DLL:', -1, 17, 27, 70, 8, WS_VISIBLE
         dialogitem 'COMBOBOX', '', 3, 37, 5, 150, 100, WS_VISIBLE + WS_BORDER + WS_TABSTOP + WS_VSCROLL + CBS_DROPDOWNLIST + CBS_HASSTRINGS
         dialogitem 'EDIT', '', 4, 37, 25, 150, 13, WS_VISIBLE + WS_BORDER + WS_TABSTOP
         dialogitem 'BUTTON', 'Refresh', 1, 193, 5, 50, 13, WS_VISIBLE + WS_TABSTOP + BS_DEFPUSHBUTTON
         dialogitem 'BUTTON','Choose', 2, 193, 25, 50, 13, WS_VISIBLE + WS_TABSTOP + BS_DEFPUSHBUTTON
         dialogitem 'BUTTON', 'Inject', 0, 5, 43, 238, 15, WS_VISIBLE + WS_TABSTOP + BS_DEFPUSHBUTTON
  enddialog
