#define UNICODE
#define _UNICODE
#include "WindowsUI.h"
#include <windows.h>
#include <commdlg.h>
#include <dwmapi.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

static HWND window, currentParent, homePanel, cardPanel;
static PVOID volatile postWindow;
static int homeScroll, cardScroll, selectedCard;
static UINT dpi=96;
static int selectedPage=100;
static ChotkiEvent callback;
static void *context;
static HFONT regular, reading, heading, smallFont, dateFont, captionFont;
static HBRUSH ground, panel;
static int automation, exitCode, priorFocus;
static wchar_t *testFilePath;
static int testFileResult;
static const COLORREF background = RGB(21,22,28), foreground = RGB(232,223,205);
static const COLORREF gold=RGB(201,162,39), muted=RGB(163,158,143), line=RGB(46,42,32);
typedef struct { int kind, flags, hover, tracked, scrolled, completed, token; WNDPROC previous; wchar_t *summary,*category,*time,*attribution,*path; double fx,fy; } Visual;
static int px(int value) { return MulDiv(value,dpi,96); }
static HWND findChild(int id) {
    HWND found=GetDlgItem(window,id);
    if(found) return found;
    if(homePanel) found=GetDlgItem(homePanel,id);
    if(!found && cardPanel) found=GetDlgItem(cardPanel,id);
    return found;
}
extern void ch_draw_art(void *context,const wchar_t *path,int x,int y,int width,int height,double fx,double fy);
extern void ch_draw_backdrop(void *dc,int width,int height,int offsetX,int offsetY);
static void backdrop(HDC dc,HWND target) {
    RECT r; GetClientRect(window,&r); POINT origin={0,0}; MapWindowPoints(target,window,&origin,1);
    ch_draw_backdrop(dc,r.right,r.bottom,origin.x,origin.y);
}
static HFONT face(int size,int weight,int serif) {
    return CreateFontW(-px(size),0,0,0,weight,0,0,0,DEFAULT_CHARSET,0,0,CLEARTYPE_QUALITY,0,serif ? L"XCharter" : L"Segoe UI");
}
static void fonts(void) {
    if(regular) { DeleteObject(regular); DeleteObject(reading); DeleteObject(heading); DeleteObject(smallFont); DeleteObject(dateFont); DeleteObject(captionFont); }
    regular=face(13,FW_NORMAL,0); reading=face(18,FW_NORMAL,1); heading=face(28,FW_BOLD,1); smallFont=face(11,FW_NORMAL,0); dateFont=face(16,FW_SEMIBOLD,0); captionFont=face(15,FW_NORMAL,1);
}
static void ink(HDC dc,HFONT font,COLORREF color) { SelectObject(dc,font); SetTextColor(dc,color); SetBkMode(dc,TRANSPARENT); }
static void roundBox(HDC dc,RECT r,COLORREF fill,COLORREF stroke,int radius) {
    HPEN pen=CreatePen(PS_SOLID,1,stroke); HBRUSH brush=CreateSolidBrush(fill);
    HGDIOBJ oldPen=SelectObject(dc,pen),oldBrush=SelectObject(dc,brush);
    RoundRect(dc,r.left,r.top,r.right,r.bottom,px(radius*2),px(radius*2));
    SelectObject(dc,oldPen); SelectObject(dc,oldBrush); DeleteObject(pen); DeleteObject(brush);
}
static void drawVisual(DRAWITEMSTRUCT *item) {
    Visual *v=GetPropW(item->hwndItem,L"ChotkiVisual"); if(!v || (v->kind==11 && !v->summary) || (v->kind==12 && !v->path)) return;
    RECT r=item->rcItem; HDC dc=item->hDC; wchar_t text[2048]; GetWindowTextW(item->hwndItem,text,2048);
    int saved=SaveDC(dc); backdrop(dc,item->hwndItem);
    int disabled=!IsWindowEnabled(item->hwndItem), focus=(item->itemState & ODS_FOCUS)!=0;
    if(v->kind==16 || v->kind==17) { HBRUSH paper=CreateSolidBrush(foreground); FillRect(dc,&r,paper); DeleteObject(paper); }
    if(v->kind==11) {
        roundBox(dc,r,foreground,foreground,22);
        RECT c=r; InflateRect(&c,-px(14),-px(14));
        ink(dc,smallFont,RGB(94,89,79));
        RECT category=c; category.bottom=category.top+px(18);
        ink(dc,regular,wcscmp(v->category,L"Fasting")==0 ? RGB(154,143,196) : gold);
        RECT symbol=category; symbol.top-=px(2); symbol.bottom=category.top+px(19); DrawTextW(dc,wcscmp(v->category,L"Reading")==0 ? L"▱" : wcscmp(v->category,L"Fasting")==0 ? L"♧" : L"⁙",-1,&symbol,DT_SINGLELINE);
        category.top+=px(24); category.bottom+=px(24); ink(dc,smallFont,RGB(94,89,79)); DrawTextW(dc,v->category,-1,&category,DT_SINGLELINE);
        c.top+=px(48);
        int size=18; HFONT title=NULL; RECT measured;
        do { if(title) { SelectObject(dc,regular); DeleteObject(title); } title=face(size,FW_BOLD,1); ink(dc,title,RGB(26,25,22)); measured=c;
             DrawTextW(dc,text,-1,&measured,DT_WORDBREAK|DT_CALCRECT); if(measured.bottom-measured.top<=px(68)) break; --size;
        } while(size>=11);
        RECT titleRect=c; titleRect.bottom=c.top+(measured.bottom-measured.top>px(68) ? px(68) : measured.bottom-measured.top);
        DrawTextW(dc,text,-1,&titleRect,DT_WORDBREAK|DT_END_ELLIPSIS);
        SelectObject(dc,regular); DeleteObject(title);
        HFONT prose=face(13,FW_NORMAL,1); ink(dc,prose,RGB(94,89,79));
        RECT detail=c; detail.top=titleRect.bottom+px(8); detail.bottom=r.bottom-px(52);
        if(r.right-r.left<px(200) && detail.bottom>detail.top+px(64)) detail.bottom=detail.top+px(64);
        DrawTextW(dc,v->summary,-1,&detail,DT_WORDBREAK|DT_END_ELLIPSIS);
        SelectObject(dc,regular); DeleteObject(prose);
        ink(dc,smallFont,RGB(94,89,79));
        RECT attribution=c; attribution.top=r.bottom-px(50); attribution.bottom=r.bottom-px(29);
        DrawTextW(dc,v->attribution,-1,&attribution,DT_WORDBREAK|DT_END_ELLIPSIS);
        RECT time=c; time.top=r.bottom-px(28); DrawTextW(dc,v->time,-1,&time,DT_SINGLELINE);
    } else if(v->kind==12) {
        HRGN clip=CreateRoundRectRgn(r.left,r.top,r.right+1,r.bottom+1,px(40),px(40)); SelectClipRgn(dc,clip);
        ch_draw_art(dc,v->path,r.left,r.top,r.right-r.left,r.bottom-r.top,v->fx,v->fy);
        RECT source=r; InflateRect(&source,-px(18),-px(18)); source.top=source.bottom-px(32);
        ink(dc,smallFont,foreground); DrawTextW(dc,v->attribution,-1,&source,DT_WORDBREAK|DT_END_ELLIPSIS);
        RECT quote=source; quote.bottom=source.top-px(6); RECT measured=quote;
        ink(dc,reading,foreground); DrawTextW(dc,text,-1,&measured,DT_WORDBREAK|DT_CALCRECT);
        quote.top=quote.bottom-(measured.bottom-measured.top); if(quote.top<r.top+px(42)) quote.top=r.top+px(42);
        DrawTextW(dc,text,-1,&quote,DT_WORDBREAK);
        RECT caption=r; caption.left+=px(18); caption.top=quote.top-px(22);
        ink(dc,smallFont,foreground); DrawTextW(dc,L"Sayings of the Church Fathers",-1,&caption,DT_SINGLELINE);
        DeleteObject(clip);
    } else if(v->kind==16) {
        int diameter=px(22); RECT circle={r.left,r.top,r.left+diameter,r.top+diameter};
        roundBox(dc,circle,(v->flags&1) ? gold : foreground,RGB(168,138,51),16);
        if(v->flags&1) { ink(dc,smallFont,background); DrawTextW(dc,L"✓",-1,&circle,DT_CENTER|DT_VCENTER|DT_SINGLELINE); }
    } else if(v->kind==17 || v->kind==18) {
        ink(dc,regular,v->kind==17 ? RGB(94,89,79) : gold); DrawTextW(dc,text,-1,&r,DT_CENTER|DT_VCENTER|DT_SINGLELINE);
    } else {
        COLORREF color=disabled ? RGB(100,97,88) : v->kind==9 ? ((v->flags&1) ? foreground : muted) : gold;
        COLORREF fill=(v->kind==9 && v->flags&1) || v->hover ? RGB(28,30,38) : background;
        if(v->kind==10) {
            fill=(v->flags&2) ? RGB(59,52,84) : RGB(26,27,34);
            if(v->flags&1) fill=background;
            roundBox(dc,r,fill,(v->flags&1) ? gold : fill,14);
            color=(v->flags&4) ? gold : (v->flags&8) ? RGB(166,58,56) : foreground;
            RECT letters=r; letters.top+=px(5); letters.bottom=letters.top+px(14); ink(dc,smallFont,muted);
            wchar_t *newline=wcschr(text,L'\n'); if(newline) { *newline=0; DrawTextW(dc,text,-1,&letters,DT_CENTER|DT_SINGLELINE); text[0]=0; wcsncpy_s(text,2048,newline+1,_TRUNCATE); }
            RECT number=r; if(newline) { number.top+=px(20); number.bottom-=px(7); } HFONT numerals=face(newline ? 17 : 13,FW_SEMIBOLD,0); ink(dc,numerals,color); DrawTextW(dc,text,-1,&number,DT_CENTER|DT_VCENTER|DT_SINGLELINE); SelectObject(dc,regular); DeleteObject(numerals);
            if(v->flags&16) { HBRUSH dot=CreateSolidBrush(gold); RECT d={r.left+(r.right-r.left)/2-1,r.bottom-px(7),r.left+(r.right-r.left)/2+2,r.bottom-px(4)}; FillRect(dc,&d,dot); DeleteObject(dot); }
        } else {
            if(v->kind!=9 || (v->flags&1) || v->hover) roundBox(dc,r,fill,v->kind==9 ? fill : line,8);
            RECT label=r; InflateRect(&label,-px(v->kind==9 ? 10 : 4),0); ink(dc,regular,color);
            DrawTextW(dc,text,-1,&label,DT_VCENTER|DT_SINGLELINE|(v->kind==9 ? DT_LEFT : DT_CENTER)|DT_END_ELLIPSIS);
        }
    }
    if(focus) { RECT f=r; InflateRect(&f,-3,-3); DrawFocusRect(dc,&f); }
    RestoreDC(dc,saved);
}
static LRESULT CALLBACK visualProcedure(HWND hwnd,UINT msg,WPARAM wp,LPARAM lp) {
    Visual *v=GetPropW(hwnd,L"ChotkiVisual"); if(!v) return DefWindowProcW(hwnd,msg,wp,lp);
    WNDPROC previous=v->previous;
    if(msg==WM_MOUSEMOVE && !v->hover) { v->hover=1; TRACKMOUSEEVENT track={sizeof(track),TME_LEAVE,hwnd,0}; TrackMouseEvent(&track); InvalidateRect(hwnd,NULL,FALSE); }
    if(msg==WM_MOUSELEAVE) { v->hover=0; InvalidateRect(hwnd,NULL,FALSE); }
    if(msg==WM_MOUSEWHEEL && GetParent(hwnd)!=window) return SendMessageW(GetParent(hwnd),msg,wp,lp);
    if(msg==WM_NCDESTROY) { RemovePropW(hwnd,L"ChotkiVisual"); free(v->summary); free(v->category); free(v->time); free(v->attribution); free(v->path); free(v); return CallWindowProcW(previous,hwnd,msg,wp,lp); }
    int userScroll=v->tracked && (msg==WM_MOUSEWHEEL || (msg==WM_VSCROLL && LOWORD(wp)!=SB_ENDSCROLL) ||
                   (msg==WM_KEYDOWN && (wp==VK_NEXT || wp==VK_PRIOR || wp==VK_DOWN || wp==VK_UP)));
    if(userScroll) v->scrolled=1;
    LRESULT result=CallWindowProcW(previous,hwnd,msg,wp,lp);
    if(userScroll && v->scrolled && !v->completed) {
        SCROLLINFO si={sizeof(si),SIF_ALL}; GetScrollInfo(hwnd,SB_VERT,&si);
        if(si.nPos+(int)si.nPage-1>=si.nMax || si.nMax==0) { v->completed=1; ch_post(-6,v->token); }
    }
    return result;
}
static LRESULT CALLBACK scrollProcedure(HWND hwnd,UINT msg,WPARAM wp,LPARAM lp) {
    if(msg==WM_DRAWITEM || msg==WM_COMMAND || msg==WM_CONTEXTMENU || msg==WM_CTLCOLORSTATIC || msg==WM_CTLCOLORBTN) return SendMessageW(window,msg,wp,lp);
    if(msg==WM_ERASEBKGND) { backdrop((HDC)wp,hwnd); return 1; }
    if(msg==WM_VSCROLL || msg==WM_HSCROLL || msg==WM_MOUSEWHEEL) {
        int bar=hwnd==cardPanel ? SB_HORZ : SB_VERT;
        SCROLLINFO si={sizeof(si),SIF_ALL}; GetScrollInfo(hwnd,bar,&si); int old=si.nPos;
        if(msg==WM_MOUSEWHEEL) si.nPos-=GET_WHEEL_DELTA_WPARAM(wp)/WHEEL_DELTA*px(48);
        else switch(LOWORD(wp)) { case SB_LINELEFT: si.nPos-=px(24); break; case SB_LINERIGHT: si.nPos+=px(24); break; case SB_PAGELEFT: si.nPos-=si.nPage; break; case SB_PAGERIGHT: si.nPos+=si.nPage; break; case SB_THUMBTRACK: si.nPos=si.nTrackPos; break; }
        si.fMask=SIF_POS; SetScrollInfo(hwnd,bar,&si,TRUE); GetScrollInfo(hwnd,bar,&si);
        if(bar==SB_HORZ) cardScroll=si.nPos; else homeScroll=si.nPos;
        ScrollWindowEx(hwnd,bar==SB_HORZ ? old-si.nPos : 0,bar==SB_VERT ? old-si.nPos : 0,NULL,NULL,NULL,NULL,SW_SCROLLCHILDREN|SW_INVALIDATE);
        UpdateWindow(hwnd); return 0;
    }
    return DefWindowProcW(hwnd,msg,wp,lp);
}

static wchar_t *wide(const char *text) {
    int length = MultiByteToWideChar(CP_UTF8, 0, text, -1, NULL, 0);
    wchar_t *result = calloc(length ? length : 1, sizeof(wchar_t));
    if (length) MultiByteToWideChar(CP_UTF8, 0, text, -1, result, length);
    return result;
}
static LRESULT CALLBACK procedure(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    switch (msg) {
    case WM_APP+10: if(callback) callback(context,(int32_t)wp,(int32_t)lp); return 0;
    case WM_SIZE: if(callback && currentParent && wp!=SIZE_MINIMIZED) callback(context,-4,0); return 0;
    case WM_DPICHANGED: { dpi=HIWORD(wp); fonts(); RECT *r=(RECT*)lp; SetWindowPos(hwnd,NULL,r->left,r->top,r->right-r->left,r->bottom-r->top,SWP_NOZORDER|SWP_NOACTIVATE); return 0; }
    case WM_DRAWITEM: drawVisual((DRAWITEMSTRUCT*)lp); return TRUE;
    case WM_TIMER:
        if (wp==1 && callback) callback(context,-2,0);
        return 0;
    case WM_ACTIVATEAPP:
        if (wp && callback && window) callback(context,-2,0);
        break;
    case WM_POWERBROADCAST:
        if (wp==PBT_APMRESUMEAUTOMATIC && callback) callback(context,-2,0);
        return TRUE;
    case WM_COMMAND:
        if (callback) callback(context, LOWORD(wp), HIWORD(wp));
        return 0;
    case WM_CONTEXTMENU: {
        int id=GetDlgCtrlID((HWND)wp);
        if(id>=1000 && id<5000) {
            selectedCard=(id%1000); if(callback) callback(context,300,50); return 0;
        }
        if(id==300) {
            POINT point={(short)LOWORD(lp),(short)HIWORD(lp)};
            if(point.x!=-1 || point.y!=-1) { ScreenToClient((HWND)wp,&point); LRESULT row=SendMessageW((HWND)wp,LB_ITEMFROMPOINT,0,MAKELPARAM(point.x,point.y)); if(HIWORD(row)) return 0; SendMessageW((HWND)wp,LB_SETCURSEL,LOWORD(row),0); }
            if(callback) callback(context,300,50); return 0;
        }
        break;
    }
    case WM_GETMINMAXINFO: {
        MINMAXINFO *size = (MINMAXINFO *)lp;
        RECT r={0,0,px(620),px(540)}; AdjustWindowRectExForDpi(&r,WS_OVERLAPPEDWINDOW,FALSE,0,dpi);
        size->ptMinTrackSize.x = r.right-r.left; size->ptMinTrackSize.y = r.bottom-r.top;
        if(automation) { size->ptMaxTrackSize.x=px(2200); size->ptMaxTrackSize.y=px(1800); }
        return 0;
    }
    case WM_CTLCOLORSTATIC:
    case WM_CTLCOLOREDIT:
    case WM_CTLCOLORLISTBOX:
    case WM_CTLCOLORBTN:
        Visual *v=GetPropW((HWND)lp,L"ChotkiVisual");
        SetTextColor((HDC)wp, v && (v->flags&64) ? muted : v && (v->flags&1024) ? RGB(154,143,196) : v && (v->flags&128) ? gold : foreground);
        SetBkColor((HDC)wp, background);
        if(v && (v->kind==0 || v->kind==5)) { SetBkMode((HDC)wp,TRANSPARENT); return (LRESULT)GetStockObject(NULL_BRUSH); }
        return (LRESULT)ground;
    case WM_ERASEBKGND: {
        backdrop((HDC)wp,hwnd); return 1;
    }
    case WM_DESTROY: InterlockedExchangePointer(&postWindow,NULL); PostQuitMessage(exitCode); return 0;
    }
    return DefWindowProcW(hwnd, msg, wp, lp);
}
static BOOL CALLBACK removeChild(HWND child, LPARAM unused) { DestroyWindow(child); return TRUE; }
static wchar_t *priorReadingText;
static int priorReadingLine;
void ch_clear(void) {
    free(priorReadingText); priorReadingText=NULL; priorReadingLine=0;
    HWND reader=findChild(301);
    if(reader) { int n=GetWindowTextLengthW(reader); priorReadingText=calloc(n+1,sizeof(wchar_t)); GetWindowTextW(reader,priorReadingText,n+1); priorReadingLine=(int)SendMessageW(reader,EM_GETFIRSTVISIBLELINE,0,0); }
    HWND focus=GetFocus(); priorFocus=focus ? GetDlgCtrlID(focus) : 0;
    EnumChildWindows(window, removeChild, 0); homePanel=NULL; cardPanel=NULL; currentParent=window;
}
void ch_control(int32_t id, int32_t kind, const char *text, int32_t x, int32_t y, int32_t width, int32_t height) {
    // 6 checkbox, 7 choice, 8 editable multiline; other kinds defined in Swift.
    const wchar_t *cls = (kind==1 || kind==6 || (kind>=9 && kind<=11) || kind==16 || kind==17 || kind==18) ? L"BUTTON" : kind==7 ? L"COMBOBOX" : kind == 2 ? L"LISTBOX" : (kind == 3 || kind == 4 || kind==8) ? L"EDIT" : L"STATIC";
    DWORD style = WS_CHILD | WS_VISIBLE;
    if (kind == 1 || (kind>=9 && kind<=11) || kind==16 || kind==17 || kind==18) style |= WS_TABSTOP | BS_OWNERDRAW;
    if (kind == 2) style |= WS_TABSTOP | LBS_NOTIFY | WS_VSCROLL | LBS_NOINTEGRALHEIGHT;
    if (kind == 3) style |= WS_TABSTOP | ES_AUTOHSCROLL | WS_BORDER;
    if (kind == 4) style |= WS_TABSTOP | ES_MULTILINE | ES_READONLY | ES_AUTOVSCROLL | WS_VSCROLL;
    if (kind == 12) style |= SS_OWNERDRAW;
    if (kind == 6) style |= WS_TABSTOP | BS_AUTOCHECKBOX | BS_MULTILINE;
    if (kind == 7) style |= WS_TABSTOP | CBS_DROPDOWNLIST | WS_VSCROLL;
    if (kind == 8) style |= WS_TABSTOP | ES_MULTILINE | ES_AUTOVSCROLL | WS_VSCROLL | WS_BORDER;
    wchar_t *value = wide(text);
    HWND parent=currentParent ? currentParent : window;
    int offsetX=parent==cardPanel ? cardScroll : 0, offsetY=parent==homePanel ? homeScroll : 0;
    HWND child = CreateWindowExW(0, cls, value, style, px(x)-offsetX, px(y)-offsetY, px(width), px(kind==7 ? height+240 : height), parent, (HMENU)(INT_PTR)id, GetModuleHandleW(NULL), NULL);
    int restoreReading=child && id==301 && kind==4 && priorReadingText && wcscmp(value,priorReadingText)==0;
    free(value);
    if (child) {
        Visual *v=calloc(1,sizeof(Visual)); v->kind=kind; SetPropW(child,L"ChotkiVisual",v);
        v->previous=(WNDPROC)SetWindowLongPtrW(child,GWLP_WNDPROC,(LONG_PTR)visualProcedure);
        SendMessageW(child, WM_SETFONT, (WPARAM)(kind == 5 ? heading : kind == 4 ? reading : regular), TRUE);
        if(restoreReading) SendMessageW(child,EM_LINESCROLL,0,priorReadingLine);
        if(id==priorFocus) SetFocus(child);
    }
}
static int isChoice(int32_t id) {
    wchar_t name[32]; GetClassNameW(findChild(id),name,32); return wcscmp(name,L"ComboBox")==0;
}
void ch_list_add(int32_t id, const char *text) {
    wchar_t *value = wide(text); SendMessageW(findChild(id), isChoice(id) ? CB_ADDSTRING : LB_ADDSTRING, 0, (LPARAM)value); free(value);
}
void ch_update(int32_t id, const char *text) {
    wchar_t *value=wide(text); SetWindowTextW(findChild(id),value); free(value);
}
int32_t ch_selected(int32_t id) { if(id==300 && cardPanel) return selectedCard; return (int32_t)SendMessageW(findChild(id), isChoice(id) ? CB_GETCURSEL : LB_GETCURSEL, 0, 0); }
void ch_select(int32_t id, int32_t index) { if(id==300 && cardPanel) { selectedCard=index; return; } SendMessageW(findChild(id), isChoice(id) ? CB_SETCURSEL : LB_SETCURSEL, index, 0); }
void ch_choose(int32_t id, int32_t index) {
    ch_select(id,index); SendMessageW(window,WM_COMMAND,MAKEWPARAM(id,1),(LPARAM)findChild(id));
}
int32_t ch_checked(int32_t id) { return SendMessageW(findChild(id),BM_GETCHECK,0,0)==BST_CHECKED; }
void ch_check(int32_t id, int32_t checked) { SendMessageW(findChild(id),BM_SETCHECK,checked ? BST_CHECKED : BST_UNCHECKED,0); }
void ch_enable(int32_t id, int32_t enabled) { EnableWindow(findChild(id),enabled); }
void ch_command(int32_t id) { SendMessageW(window,WM_COMMAND,MAKEWPARAM(id,0),0); }
void ch_rule_menu(int32_t paused, int32_t dispensed) {
    HMENU menu=CreatePopupMenu(), removal=CreatePopupMenu();
    UINT status=MF_STRING | (dispensed ? MF_GRAYED : 0);
    AppendMenuW(menu,status,450,L"Mark kept"); AppendMenuW(menu,status,451,L"Mark kept late");
    AppendMenuW(menu,status,452,L"Reset this day"); AppendMenuW(menu,status,453,L"Stand down for this day");
    AppendMenuW(menu,MF_SEPARATOR,0,NULL); AppendMenuW(menu,MF_STRING,454,L"Edit rule…");
    AppendMenuW(menu,MF_STRING,455,paused ? L"Resume from today" : L"Pause from today");
    AppendMenuW(removal,MF_STRING,460,L"Just this day");
    AppendMenuW(removal,MF_STRING,461,L"This day and after");
    AppendMenuW(removal,MF_STRING,462,L"The whole rule");
    AppendMenuW(menu,MF_POPUP,(UINT_PTR)removal,L"Remove");
    POINT point; GetCursorPos(&point);
    UINT selected=TrackPopupMenu(menu,TPM_RETURNCMD | TPM_RIGHTBUTTON,point.x,point.y,0,window,NULL);
    DestroyMenu(menu);
    if(selected) ch_command(selected);
}
int32_t ch_text(int32_t id, char *buffer, int32_t length) {
    HWND child = findChild(id); int count = GetWindowTextLengthW(child) + 1;
    wchar_t *value = calloc(count,sizeof(wchar_t)); GetWindowTextW(child,value,count);
    int needed=WideCharToMultiByte(CP_UTF8,0,value,-1,NULL,0,NULL,NULL);
    if(!buffer || length==0) { free(value); return needed; }
    if(length<needed) { free(value); return -needed; }
    int result = WideCharToMultiByte(CP_UTF8,0,value,-1,buffer,length,NULL,NULL); free(value); return result;
}
int32_t ch_click(int32_t id) {
    HWND child = findChild(id); if (!child || !IsWindowEnabled(child)) return 0;
    SendMessageW(child, BM_CLICK, 0, 0); return 1;
}
void ch_close(int32_t code) { exitCode = code; DestroyWindow(window); }
void ch_exit(int32_t code) { fflush(NULL); ExitProcess((UINT)code); }
void ch_error(const char *message) {
    wchar_t *value = wide(message); MessageBoxW(window,value,L"Chotki",MB_OK | MB_ICONINFORMATION); free(value);
}
void ch_test_file_dialog(const char *path, int32_t result) {
    if(!automation) return;
    free(testFilePath); testFilePath=wide(path); testFileResult=result;
}
int32_t ch_file_dialog(int32_t save, const char *suggested, char *path, int32_t length) {
    wchar_t file[32768]={0};
    if(automation) {
        int result=testFileResult; testFileResult=0;
        if(result!=1) { free(testFilePath); testFilePath=NULL; return result; }
        if(!testFilePath) return -1;
        wcsncpy_s(file,32768,testFilePath,_TRUNCATE); free(testFilePath); testFilePath=NULL;
    } else {
        wchar_t *name=wide(suggested); wcsncpy_s(file,32768,name,_TRUNCATE); free(name);
        OPENFILENAMEW dialog; ZeroMemory(&dialog,sizeof(dialog));
        dialog.lStructSize=sizeof(dialog); dialog.hwndOwner=window;
        dialog.lpstrFilter=L"Chotki backup (*.json)\0*.json\0All files (*.*)\0*.*\0\0";
        dialog.lpstrFile=file; dialog.nMaxFile=32768; dialog.lpstrDefExt=L"json";
        dialog.lpstrTitle=save ? L"Export a backup" : L"Restore from a backup";
        dialog.Flags=OFN_EXPLORER | OFN_NOCHANGEDIR | OFN_PATHMUSTEXIST |
                     (save ? OFN_OVERWRITEPROMPT : OFN_FILEMUSTEXIST);
        if(!(save ? GetSaveFileNameW(&dialog) : GetOpenFileNameW(&dialog)))
            return CommDlgExtendedError() ? -1 : 0;
    }
    int needed=WideCharToMultiByte(CP_UTF8,0,file,-1,NULL,0,NULL,NULL);
    if(needed<=0 || needed>length) return -1;
    return WideCharToMultiByte(CP_UTF8,0,file,-1,path,length,NULL,NULL) ? 1 : -1;
}
int32_t ch_capture(const char *path) {
    RedrawWindow(window,NULL,NULL,RDW_INVALIDATE | RDW_ALLCHILDREN | RDW_UPDATENOW);
    RECT r; GetClientRect(window,&r); int width=r.right, height=r.bottom;
    BITMAPINFO info; ZeroMemory(&info,sizeof(info));
    info.bmiHeader.biSize=sizeof(BITMAPINFOHEADER); info.bmiHeader.biWidth=width; info.bmiHeader.biHeight=height;
    info.bmiHeader.biPlanes=1; info.bmiHeader.biBitCount=32; info.bmiHeader.biCompression=BI_RGB;
    HDC screen=GetDC(window), memory=CreateCompatibleDC(screen); void *pixels=NULL;
    HBITMAP bitmap=CreateDIBSection(screen,&info,DIB_RGB_COLORS,&pixels,NULL,0);
    HGDIOBJ old=SelectObject(memory,bitmap);
    int ok=PrintWindow(window,memory,PW_CLIENTONLY); GdiFlush();
    // A noninteractive SSH desktop can return success with an empty bitmap.
    if(ok) {
        unsigned char *bytes=pixels; int hasColor=0;
        for(int i=0;i<width*height*4;i++) if(bytes[i]) { hasColor=1; break; }
        if(!hasColor) ok=0;
    }
    if (ok) {
        BITMAPFILEHEADER file; ZeroMemory(&file,sizeof(file));
        file.bfType=0x4d42; file.bfOffBits=sizeof(file)+sizeof(info.bmiHeader); file.bfSize=file.bfOffBits+width*height*4;
        wchar_t *name=wide(path); HANDLE handle=CreateFileW(name,GENERIC_WRITE,0,NULL,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,NULL); free(name);
        if (handle==INVALID_HANDLE_VALUE) ok=0;
        else { DWORD written; ok=WriteFile(handle,&file,sizeof(file),&written,NULL) && WriteFile(handle,&info.bmiHeader,sizeof(info.bmiHeader),&written,NULL) && WriteFile(handle,pixels,width*height*4,&written,NULL); CloseHandle(handle); }
    }
    SelectObject(memory,old); DeleteObject(bitmap); DeleteDC(memory); ReleaseDC(window,screen); return ok;
}
void ch_post(int32_t control, int32_t event) {
    HWND target=InterlockedCompareExchangePointer(&postWindow,NULL,NULL);
    if(target) PostMessageW(target,WM_APP+10,(WPARAM)(INT_PTR)control,(LPARAM)event);
}
void ch_pump(void) {
    MSG msg; while(PeekMessageW(&msg,NULL,0,0,PM_REMOVE)) {
        if(msg.message==WM_QUIT) { PostQuitMessage((int)msg.wParam); break; }
        TranslateMessage(&msg); DispatchMessageW(&msg);
    }
}
int32_t ch_width(void) { RECT r; GetClientRect(window,&r); return MulDiv(r.right,96,dpi); }
int32_t ch_height(void) { RECT r; GetClientRect(window,&r); return MulDiv(r.bottom,96,dpi); }
int32_t ch_font(const char *path) { wchar_t *value=wide(path); int result=AddFontResourceExW(value,FR_PRIVATE,0); free(value); return result; }
int32_t ch_reading_face(char *buffer,int32_t length) {
    HDC dc=GetDC(window); HGDIOBJ old=SelectObject(dc,reading); wchar_t value[128]; GetTextFaceW(dc,128,value);
    SelectObject(dc,old); ReleaseDC(window,dc);
    return WideCharToMultiByte(CP_UTF8,0,value,-1,buffer,length,NULL,NULL);
}
void ch_style(int32_t id,int32_t flags) { HWND handle=findChild(id); Visual *v=GetPropW(handle,L"ChotkiVisual"); if(v) { v->flags=flags; if(flags&256) SendMessageW(handle,WM_SETFONT,(WPARAM)dateFont,TRUE); else if(flags&512) SendMessageW(handle,WM_SETFONT,(WPARAM)smallFont,TRUE); else if(flags&1024) SendMessageW(handle,WM_SETFONT,(WPARAM)captionFont,TRUE); InvalidateRect(handle,NULL,FALSE); } }
static void panelScroll(HWND handle,int bar,int total,int page,int position) {
    SCROLLINFO si={sizeof(si),SIF_RANGE|SIF_PAGE|SIF_POS,0,px(total)-1,px(page),position,0};
    SetScrollInfo(handle,bar,&si,TRUE); si.fMask=SIF_POS; GetScrollInfo(handle,bar,&si);
    if(bar==SB_HORZ) { cardScroll=si.nPos; ShowScrollBar(handle,SB_HORZ,FALSE); } else homeScroll=si.nPos;
}
void ch_home_begin(int32_t x,int32_t y,int32_t width,int32_t height,int32_t contentHeight) {
    homePanel=CreateWindowExW(0,L"ChotkiScroll",L"The day",WS_CHILD|WS_VISIBLE|WS_CLIPCHILDREN|WS_VSCROLL,
                             px(x),px(y),px(width),px(height),window,(HMENU)9008,GetModuleHandleW(NULL),NULL);
    panelScroll(homePanel,SB_VERT,contentHeight,height,homeScroll); currentParent=homePanel;
}
void ch_home_end(void) { currentParent=window; }
void ch_cards_begin(int32_t x,int32_t y,int32_t width,int32_t height,int32_t contentWidth) {
    cardPanel=CreateWindowExW(0,L"ChotkiScroll",L"Today's commitments",WS_CHILD|WS_VISIBLE|WS_CLIPCHILDREN|WS_HSCROLL,
                             px(x),px(y)-homeScroll,px(width),px(height),homePanel,(HMENU)9009,GetModuleHandleW(NULL),NULL);
    panelScroll(cardPanel,SB_HORZ,contentWidth,width,cardScroll); currentParent=cardPanel;
}
void ch_cards_end(void) { currentParent=homePanel; }
void ch_card(int32_t id,const char *title,const char *summary,const char *category,const char *time,const char *attribution,int32_t x,int32_t width,int32_t height) {
    ch_control(id,11,title,x,0,width,height);
    Visual *v=GetPropW(findChild(id),L"ChotkiVisual"); if(!v) return;
    v->summary=wide(summary); v->category=wide(category); v->time=wide(time); v->attribution=wide(attribution);
}
void ch_image(int32_t id,const char *path,const char *quote,const char *source,double fx,double fy,int32_t x,int32_t y,int32_t width,int32_t height) {
    ch_control(id,12,quote,x,y,width,height);
    Visual *v=GetPropW(findChild(id),L"ChotkiVisual"); if(!v) return;
    v->path=wide(path); v->attribution=wide(source); v->fx=fx; v->fy=fy;
}
void ch_reset_home_scroll(void) { homeScroll=0; cardScroll=0; }
void ch_test_resize(int32_t width,int32_t height) {
    if(!automation) return;
    RECT r={0,0,px(width),px(height)}; AdjustWindowRectExForDpi(&r,WS_OVERLAPPEDWINDOW,FALSE,0,dpi);
    SetWindowPos(window,NULL,0,0,r.right-r.left,r.bottom-r.top,SWP_NOMOVE|SWP_NOZORDER|SWP_NOACTIVATE);
}
void ch_track_reading(int32_t id,int32_t token) {
    Visual *v=GetPropW(findChild(id),L"ChotkiVisual"); if(v) { v->tracked=1; v->token=token; v->scrolled=0; v->completed=0; }
}
void ch_test_scroll_end(int32_t id,int32_t deliberate) {
    if(!automation) return;
    if(deliberate) SendMessageW(findChild(id),WM_VSCROLL,SB_BOTTOM,0);
    else SendMessageW(findChild(id),EM_LINESCROLL,0,100000);
}
int32_t ch_run(ChotkiEvent event, void *data, int32_t automated) {
    callback=event; context=data; automation=automated;
    SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
    dpi=GetDpiForSystem();
    ground=CreateSolidBrush(background); panel=CreateSolidBrush(RGB(28,30,38));
    fonts();
    WNDCLASSW cls; ZeroMemory(&cls,sizeof(cls)); cls.lpfnWndProc=procedure; cls.hInstance=GetModuleHandleW(NULL);
    cls.hCursor=LoadCursorW(NULL,IDC_ARROW); cls.hbrBackground=ground; cls.lpszClassName=L"ChotkiWindows";
    if(!RegisterClassW(&cls)) return 2;
    WNDCLASSW scrollClass; ZeroMemory(&scrollClass,sizeof(scrollClass)); scrollClass.lpfnWndProc=scrollProcedure; scrollClass.hInstance=cls.hInstance; scrollClass.hCursor=cls.hCursor; scrollClass.lpszClassName=L"ChotkiScroll"; RegisterClassW(&scrollClass);
    RECT frame={0,0,px(1100),px(860)}; AdjustWindowRectExForDpi(&frame,WS_OVERLAPPEDWINDOW,FALSE,0,dpi);
    window=CreateWindowExW(0,cls.lpszClassName,automated ? L"Chotki — Review" : L"Chotki",WS_OVERLAPPEDWINDOW,CW_USEDEFAULT,CW_USEDEFAULT,frame.right-frame.left,frame.bottom-frame.top,NULL,NULL,cls.hInstance,NULL);
    if(!window) return 3;
    currentParent=window; InterlockedExchangePointer(&postWindow,window);
    BOOL dark=TRUE; DwmSetWindowAttribute(window,20,&dark,sizeof(dark));
    callback(context,0,0); ShowWindow(window,automation ? SW_SHOWNOACTIVATE : SW_SHOW); UpdateWindow(window);
    SetTimer(window,1,60000,NULL);
    if(automation) callback(context,-1,0);
    MSG msg; int result;
    while((result=GetMessageW(&msg,NULL,0,0))>0) { if(!IsDialogMessageW(window,&msg)){TranslateMessage(&msg); DispatchMessageW(&msg);} }
    DeleteObject(regular); DeleteObject(reading); DeleteObject(heading); DeleteObject(smallFont); DeleteObject(dateFont); DeleteObject(captionFont); DeleteObject(ground); DeleteObject(panel);
    free(testFilePath); testFilePath=NULL;
    return result<0 ? 4 : (int32_t)msg.wParam;
}

int32_t ch_first_visible_line(int32_t id) { return (int32_t)SendMessageW(findChild(id),EM_GETFIRSTVISIBLELINE,0,0); }
