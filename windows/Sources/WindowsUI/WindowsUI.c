#define UNICODE
#define _UNICODE
#include "WindowsUI.h"
#include <windows.h>
#include <commdlg.h>
#include <commctrl.h>
#include <dwmapi.h>
#include <richedit.h>
#include <shellapi.h>
#include <ole2.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

extern int ch_opening_active(void);
extern int ch_opening_state(void);
extern void ch_opening_resize(void *parent);
extern void ch_opening_start(void *parent,int skip);
extern int ch_opening_fixture(void *parent,double milliseconds);
extern void ch_opening_shutdown(void);
extern void ch_opening_paint(void *dc);
static HWND window, currentParent, homePanel, cardPanel, glossaryPanel;
static HANDLE instanceMutex;
static int lifecycleReview;
static const wchar_t *mainClass(void) { return lifecycleReview ? L"ChotkiWindowsLifecycleReview" : L"ChotkiWindows"; }
static int startHidden, platformReview;
static HWND glossaryFocus, readerParking, pooledReaders[2], reportWindow;
static HMODULE richLibrary;
typedef struct LinkRange { LONG start, end; int32_t id; int disclosure; struct LinkRange *next; } LinkRange;
typedef struct ReadingRange { LONG end; int32_t token; int completed; struct ReadingRange *next; } ReadingRange;
static PVOID volatile postWindow;
static int homeScroll, cardScroll, selectedCard;
static UINT dpi=96;
static int selectedPage=100;
typedef struct { int anchor,first,count,height,active; } LibraryHover;
static LibraryHover libraryHovers[128];
static int libraryHoverCount;
static ChotkiEvent callback;
static void *context;
static HFONT regular, reading, heading, smallFont, dateFont, captionFont, listFont;
static HBRUSH ground, panel;
static int automation, exitCode, priorFocus, readerSerial, prayerKeys, renderDepth, renderLocked, keyboardFocus;
static wchar_t *testFilePath;
static int testFileResult;
static const COLORREF background = RGB(21,22,28), foreground = RGB(232,223,205);
static const COLORREF gold=RGB(201,162,39), muted=RGB(163,158,143), line=RGB(46,42,32);
static const COLORREF parchmentDim=RGB(216,207,189), violet=RGB(154,143,196);
typedef struct ChoiceItem { wchar_t *title,*group; int index; struct ChoiceItem *next; } ChoiceItem;
typedef struct { int count,target,choice; ChoiceItem *choices; int kind, flags, nativePaint, contentHeight, hover, tracked, scrolled, completed, token, restoreLine, serial, suppressScroll, wheelRemainder, paintCount; LinkRange *links; ReadingRange *ends; WNDPROC previous; HFONT customFont; ULONGLONG attentionUntil; wchar_t *summary,*category,*time,*attribution,*path; double fx,fy; } Visual;
static int px(int value) { return MulDiv(value,dpi,96); }
static HWND findChild(int id) {
    HWND found=GetDlgItem(window,id);
    if(found) return found;
    if(glossaryPanel) found=GetDlgItem(glossaryPanel,id);
    if(!found && homePanel) found=GetDlgItem(homePanel,id);
    if(!found && cardPanel) found=GetDlgItem(cardPanel,id);
    if(!found && reportWindow) found=GetDlgItem(reportWindow,id);
    return found;
}
static void updateLibraryHover(POINT pointer) {
    for(int i=0;i<libraryHoverCount;i++) {
        LibraryHover *row=&libraryHovers[i]; HWND anchor=findChild(row->anchor);
        if(!anchor) continue;
        RECT r; GetWindowRect(anchor,&r); r.left-=px(4); r.right+=px(150); r.top-=px(3); r.bottom=r.top+px(row->height);
        int inside=PtInRect(&r,pointer) && IsWindowVisible(anchor);
        if(inside==row->active) continue;
        row->active=inside;
        for(int j=0;j<row->count;j++) { HWND link=findChild(row->first+j); if(link) ShowWindow(link,inside ? SW_SHOWNA : SW_HIDE); }
    }
}
extern void ch_draw_art(void *context,const wchar_t *path,int x,int y,int width,int height,double fx,double fy,int stationary,double progress,int imageNumber);
extern void ch_draw_border(void *dc,int x,int y,int width,int height,int scaleDpi);
extern void ch_draw_knots(void *context,int x,int y,int width,int count,int target,int diameter,int step);
extern void ch_draw_backdrop(void *dc,int width,int height,int offsetX,int offsetY);
static void backdrop(HDC dc,HWND target) {
    RECT r; GetClientRect(window,&r); POINT origin={0,0}; MapWindowPoints(target,window,&origin,1);
    ch_draw_backdrop(dc,r.right,r.bottom,origin.x,origin.y);
}
static HFONT face(int size,int weight,int serif) {
    return CreateFontW(-px(size),0,0,0,weight,0,0,0,DEFAULT_CHARSET,0,0,CLEARTYPE_QUALITY,0,serif ? L"XCharter" : L"Segoe UI");
}
static void fonts(void) {
    if(regular) { DeleteObject(regular); DeleteObject(reading); DeleteObject(heading); DeleteObject(smallFont); DeleteObject(dateFont); DeleteObject(captionFont); DeleteObject(listFont); }
    regular=face(13,FW_NORMAL,0); reading=face(18,FW_NORMAL,1); heading=face(28,FW_BOLD,1); smallFont=face(11,FW_NORMAL,0); dateFont=face(16,FW_SEMIBOLD,0); captionFont=face(15,FW_NORMAL,1); listFont=face(15,FW_NORMAL,0);
}
static void ink(HDC dc,HFONT font,COLORREF color) { SelectObject(dc,font); SetTextColor(dc,color); SetBkMode(dc,TRANSPARENT); }
static void roundBox(HDC dc,RECT r,COLORREF fill,COLORREF stroke,int radius) {
    HPEN pen=CreatePen(PS_SOLID,1,stroke); HBRUSH brush=CreateSolidBrush(fill);
    HGDIOBJ oldPen=SelectObject(dc,pen),oldBrush=SelectObject(dc,brush);
    RoundRect(dc,r.left,r.top,r.right,r.bottom,px(radius*2),px(radius*2));
    SelectObject(dc,oldPen); SelectObject(dc,oldBrush); DeleteObject(pen); DeleteObject(brush);
}
typedef struct { wchar_t text[512]; int separator,submenu; } MenuVisual;
void ch_menu_style(void *opaque) {
    HMENU menu=(HMENU)opaque; MENUINFO info={sizeof(info),MIM_BACKGROUND}; info.hbrBack=panel; SetMenuInfo(menu,&info);
    for(int i=0;i<GetMenuItemCount(menu);i++) {
        MENUITEMINFOW item={sizeof(item)}; item.fMask=MIIM_FTYPE|MIIM_SUBMENU|MIIM_STRING; wchar_t text[512]={0}; item.dwTypeData=text; item.cch=511;
        GetMenuItemInfoW(menu,i,TRUE,&item);
        MenuVisual *v=calloc(1,sizeof(*v)); wcsncpy_s(v->text,512,text,_TRUNCATE); v->separator=(item.fType&MFT_SEPARATOR)!=0; v->submenu=item.hSubMenu!=NULL;
        if(item.hSubMenu) ch_menu_style(item.hSubMenu);
        item.fMask=MIIM_FTYPE|MIIM_DATA; item.fType=MFT_OWNERDRAW; item.dwItemData=(ULONG_PTR)v; SetMenuItemInfoW(menu,i,TRUE,&item);
    }
}
static void releaseMenuItems(HMENU menu) {
    for(int i=0;i<GetMenuItemCount(menu);i++) {
        MENUITEMINFOW item={sizeof(item)}; item.fMask=MIIM_DATA|MIIM_SUBMENU; GetMenuItemInfoW(menu,i,TRUE,&item);
        if(item.hSubMenu) releaseMenuItems(item.hSubMenu);
        free((void*)item.dwItemData);
    }
}
void ch_menu_destroy(void *opaque) { HMENU menu=(HMENU)opaque; releaseMenuItems(menu); DestroyMenu(menu); }
static void drawMenu(DRAWITEMSTRUCT *item) {
    MenuVisual *v=(MenuVisual*)item->itemData; if(!v) return;
    HDC dc=item->hDC; RECT r=item->rcItem; int saved=SaveDC(dc);
    HBRUSH brush=CreateSolidBrush(item->itemState&ODS_SELECTED ? RGB(46,42,32) : RGB(28,30,38)); FillRect(dc,&r,brush); DeleteObject(brush);
    if(v->separator) { RECT separator={r.left+px(12),(r.top+r.bottom)/2,r.right-px(12),(r.top+r.bottom)/2+1}; HBRUSH b=CreateSolidBrush(line); FillRect(dc,&separator,b); DeleteObject(b); }
    else {
        ink(dc,regular,item->itemState&ODS_DISABLED ? muted : foreground);
        RECT label=r; label.left+=px(32); label.right-=px(24); DrawTextW(dc,v->text,-1,&label,DT_LEFT|DT_VCENTER|DT_SINGLELINE);
        ink(dc,regular,gold);
        if(item->itemState&ODS_CHECKED) { RECT tick=r; tick.right=tick.left+px(28); DrawTextW(dc,L"✓",-1,&tick,DT_CENTER|DT_VCENTER|DT_SINGLELINE); }
        if(v->submenu) { RECT arrow=r; arrow.left=arrow.right-px(22); DrawTextW(dc,L"›",-1,&arrow,DT_CENTER|DT_VCENTER|DT_SINGLELINE); }
    }
    RestoreDC(dc,saved);
}
static void freeChoices(Visual *v) {
    while(v->choices) { ChoiceItem *next=v->choices->next; free(v->choices->title); free(v->choices->group); free(v->choices); v->choices=next; }
}
static void sidebarIcon(HDC dc,int id,int x,int y,COLORREF color) {
    HPEN pen=CreatePen(PS_SOLID,max(1,px(1)),color); HGDIOBJ oldPen=SelectObject(dc,pen),oldBrush=SelectObject(dc,GetStockObject(NULL_BRUSH));
    int a=px(18), s=px(3), m=px(9);
    if(id==90) { RoundRect(dc,x+s,y+px(2),x+a-s,y+a-px(2),px(2),px(2)); MoveToEx(dc,x+px(7),y+px(2),NULL); LineTo(dc,x+px(7),y+a-px(2)); }
    else if(id==100) { RoundRect(dc,x+s,y+px(4),x+a-s,y+a-px(2),px(2),px(2)); MoveToEx(dc,x+s,y+px(8),NULL); LineTo(dc,x+a-s,y+px(8)); MoveToEx(dc,x+px(6),y+px(2),NULL); LineTo(dc,x+px(6),y+px(6)); MoveToEx(dc,x+px(12),y+px(2),NULL); LineTo(dc,x+px(12),y+px(6)); }
    else if(id==102) { for(int k=0;k<6;k++) { double angle=6.283185307179586*k/6; int cx=x+m+(int)(px(5)*cos(angle)),cy=y+m+(int)(px(5)*sin(angle)); Ellipse(dc,cx-px(1),cy-px(1),cx+px(2),cy+px(2)); } }
    else if(id==103) { MoveToEx(dc,x+m,y+px(4),NULL); LineTo(dc,x+m,y+a-px(3)); MoveToEx(dc,x+m,y+px(5),NULL); LineTo(dc,x+px(4),y+px(3)); LineTo(dc,x+px(3),y+a-px(4)); LineTo(dc,x+m,y+a-px(3)); MoveToEx(dc,x+m,y+px(5),NULL); LineTo(dc,x+a-px(4),y+px(3)); LineTo(dc,x+a-px(3),y+a-px(4)); LineTo(dc,x+m,y+a-px(3)); }
    else if(id==106) { RoundRect(dc,x+px(4),y+px(2),x+a-px(4),y+a-px(2),px(2),px(2)); MoveToEx(dc,x+px(7),y+px(2),NULL); LineTo(dc,x+px(7),y+a-px(2)); MoveToEx(dc,x+px(9),y+px(7),NULL); LineTo(dc,x+px(12),y+px(7)); MoveToEx(dc,x+px(9),y+px(10),NULL); LineTo(dc,x+px(12),y+px(10)); }
    else if(id==104) { MoveToEx(dc,x+px(3),y+a-px(3),NULL); LineTo(dc,x+a-px(2),y+a-px(3)); MoveToEx(dc,x+px(3),y+a-px(3),NULL); LineTo(dc,x+px(3),y+px(3)); MoveToEx(dc,x+px(5),y+px(12),NULL); LineTo(dc,x+px(9),y+px(9)); LineTo(dc,x+px(12),y+px(11)); LineTo(dc,x+px(15),y+px(5)); }
    else if(id==101) { for(int row=0;row<2;row++) for(int col=0;col<2;col++) RoundRect(dc,x+px(3+col*7),y+px(3+row*7),x+px(8+col*7),y+px(8+row*7),px(1),px(1)); }
    else if(id==105) {
        // E713 is the standard Settings glyph in Windows' icon font.
        HFONT gear=CreateFontW(-px(17),0,0,0,FW_NORMAL,0,0,0,DEFAULT_CHARSET,0,0,
                               CLEARTYPE_QUALITY,0,L"Segoe MDL2 Assets");
        HGDIOBJ prior=SelectObject(dc,gear); RECT bounds={x,y,x+a,y+a};
        SetBkMode(dc,TRANSPARENT); SetTextColor(dc,color);
        DrawTextW(dc,L"\xE713",-1,&bounds,DT_CENTER|DT_VCENTER|DT_SINGLELINE);
        SelectObject(dc,prior); DeleteObject(gear);
    }
    SelectObject(dc,oldBrush); SelectObject(dc,oldPen); DeleteObject(pen);
}
static void calendarChevron(HDC dc,int id,RECT r) {
    int cx=(r.left+r.right)/2,cy=(r.top+r.bottom)/2,wide=id==713 ? px(11) : px(4), high=id==713 ? px(3) : px(6);
    HPEN pen=CreatePen(PS_SOLID,max(1,px(1)),gold); HGDIOBJ old=SelectObject(dc,pen);
    if(id==711) { MoveToEx(dc,cx+wide,cy-high,NULL); LineTo(dc,cx-wide,cy); LineTo(dc,cx+wide,cy+high); }
    else if(id==712) { MoveToEx(dc,cx-wide,cy-high,NULL); LineTo(dc,cx+wide,cy); LineTo(dc,cx-wide,cy+high); }
    else { int up=0; wchar_t title[4]={0}; GetWindowTextW(GetDlgItem(window,713),title,4); up=wcscmp(title,L"⌃")==0; MoveToEx(dc,cx-wide,cy+(up ? high : -high),NULL); LineTo(dc,cx,cy+(up ? -high : high)); LineTo(dc,cx+wide,cy+(up ? high : -high)); }
    SelectObject(dc,old); DeleteObject(pen);
}
static void drawVisualContent(DRAWITEMSTRUCT *item) {
    Visual *v=GetPropW(item->hwndItem,L"ChotkiVisual"); if(!v || (v->kind==11 && !v->summary) || (v->kind==12 && !v->path)) return;
    RECT r=item->rcItem; HDC dc=item->hDC; wchar_t text[2048]; GetWindowTextW(item->hwndItem,text,2048);
    int saved=SaveDC(dc);
    // WM_PRINTCLIENT supplies a shared parent DC without BeginPaint's child
    // clip. Keep backdrop fills inside this control, including offscreen rows.
    IntersectClipRect(dc,r.left,r.top,r.right,r.bottom);
    // The ornamental frame overlaps the reader. It paints only its edges;
    // filling its interior would obscure text in WM_PRINTCLIENT captures.
    if(v->kind!=26) backdrop(dc,item->hwndItem);
    int disabled=!IsWindowEnabled(item->hwndItem), focus=(item->itemState & ODS_FOCUS)!=0;
    if(v->kind==16 || v->kind==17) { HBRUSH paper=CreateSolidBrush(foreground); FillRect(dc,&r,paper); DeleteObject(paper); }
    if(v->kind==0 || v->kind==5 || v->kind==25) {
        HFONT font=(HFONT)SendMessageW(item->hwndItem,WM_GETFONT,0,0);
        ink(dc,font ? font : regular,v->flags&16384 ? RGB(136,132,121) : v->flags&64 ? muted : v->flags&1024 ? RGB(154,143,196) : v->flags&128 ? gold : foreground);
        DrawTextW(dc,text,-1,&r,DT_NOPREFIX|DT_WORDBREAK|(v->kind==25 ? DT_CENTER : DT_LEFT));
    } else if(v->kind==28) {
        int center=(r.left+r.right)/2, top=(r.top+r.bottom-px(98))/2;
        RECT circle={center-px(28),top,center+px(28),top+px(56)};
        roundBox(dc,circle,v->hover ? RGB(46,42,32) : RGB(28,30,38),gold,56);
        int cy=(circle.top+circle.bottom)/2;
        int stroke=max(2,px(2)), arm=px(8); HBRUSH plus=CreateSolidBrush(gold);
        RECT horizontal={center-arm,cy-stroke/2,center+arm,cy+(stroke+1)/2};
        RECT vertical={center-stroke/2,cy-arm,center+(stroke+1)/2,cy+arm};
        FillRect(dc,&horizontal,plus); FillRect(dc,&vertical,plus); DeleteObject(plus);
        RECT label={r.left,top+px(72),r.right,top+px(98)};
        ink(dc,regular,gold); DrawTextW(dc,text,-1,&label,DT_CENTER|DT_SINGLELINE);
    } else if(v->kind==26) { ch_draw_border(dc,r.left,r.top,r.right-r.left,r.bottom-r.top,dpi); }
    else if(v->kind==6) {
        RECT box=r; box.right=box.left+px(14); box.top+=(box.bottom-box.top-px(14))/2; box.bottom=box.top+px(14);
        int checked=SendMessageW(item->hwndItem,BM_GETCHECK,0,0)==BST_CHECKED;
        roundBox(dc,box,checked ? gold : RGB(28,30,38),disabled ? RGB(68,66,60) : gold,3);
        if(checked) { ink(dc,smallFont,background); DrawTextW(dc,L"✓",-1,&box,DT_CENTER|DT_VCENTER|DT_SINGLELINE); }
        RECT label=r; label.left+=px(20); ink(dc,regular,disabled ? muted : foreground); DrawTextW(dc,text,-1,&label,DT_LEFT|DT_VCENTER|DT_SINGLELINE|DT_END_ELLIPSIS);
    } else if(v->kind==7) {
        int selectionField=item->itemID==(UINT)-1 || (item->itemState&ODS_COMBOBOXEDIT);
        if(item->itemID!=(UINT)-1) SendMessageW(item->hwndItem,CB_GETLBTEXT,item->itemID,(LPARAM)text);
        COLORREF fill=(item->itemState&ODS_SELECTED) && !selectionField ? RGB(46,42,32) : RGB(28,30,38);
        roundBox(dc,r,fill,selectionField ? line : fill,5);
        RECT label=r; label.left+=px(8); label.right-=px(selectionField ? 24 : 8);
        ink(dc,regular,disabled ? muted : foreground); DrawTextW(dc,text,-1,&label,DT_LEFT|DT_VCENTER|DT_SINGLELINE|DT_END_ELLIPSIS);
        if(selectionField) {
            RECT arrow=r; arrow.left=arrow.right-px(22); ink(dc,smallFont,disabled ? muted : gold); DrawTextW(dc,L"⌄",-1,&arrow,DT_CENTER|DT_VCENTER|DT_SINGLELINE);
        }
    } else if(v->kind==27) {
        v->flags=(v->flags&~1)|(SendMessageW(item->hwndItem,BM_GETCHECK,0,0)==BST_CHECKED ? 1 : 0);
        RECT label=r; label.right-=px(48); ink(dc,regular,IsWindowEnabled(item->hwndItem) ? foreground : muted);
        DrawTextW(dc,text,-1,&label,DT_LEFT|DT_VCENTER|DT_SINGLELINE|DT_END_ELLIPSIS);
        RECT track=r; track.left=track.right-px(34); track.top+=(track.bottom-track.top-px(18))/2; track.bottom=track.top+px(18);
        HBRUSH fill=CreateSolidBrush(v->flags&1 ? gold : RGB(68,66,60)); HGDIOBJ old=SelectObject(dc,fill); HGDIOBJ oldPen=SelectObject(dc,GetStockObject(NULL_PEN));
        RoundRect(dc,track.left,track.top,track.right,track.bottom,px(18),px(18));
        SelectObject(dc,old); DeleteObject(fill);
        int knob=v->flags&1 ? track.right-px(16) : track.left+px(2);
        fill=CreateSolidBrush(foreground); old=SelectObject(dc,fill); Ellipse(dc,knob,track.top+px(2),knob+px(14),track.bottom-px(2));
        SelectObject(dc,old); SelectObject(dc,oldPen); DeleteObject(fill);
    } else if(v->kind==20) {
        int compact=v->flags&1;
        HFONT number=face(compact ? 40 : 64,FW_LIGHT,0);
        RECT counter=r; counter.bottom=counter.top+px(compact ? 48 : 72);
        wchar_t count[32]; swprintf_s(count,32,L"%d",v->count);
        ink(dc,number,gold); DrawTextW(dc,count,-1,&counter,DT_CENTER|DT_VCENTER|DT_SINGLELINE);
        SelectObject(dc,regular); DeleteObject(number);
        RECT caption=r; caption.top+=px(compact ? 48 : 76); caption.bottom=caption.top+px(18);
        wchar_t target[48]; swprintf_s(target,48,v->count>=v->target ? L"the knot is complete" : L"of %d",v->target);
        ink(dc,regular,v->count>=v->target ? gold : muted); DrawTextW(dc,target,-1,&caption,DT_CENTER|DT_SINGLELINE);
        int step=px(compact ? 9 : 12), diameter=px(compact ? 5 : 7), top=r.top+px(compact ? 66 : 100);
        ch_draw_knots(dc,r.left,top,r.right-r.left,v->count,v->target,diameter,step);
    } else if(v->kind==22 || v->kind==23) {
        int selected=v->kind==22 || (v->flags&1);
        roundBox(dc,r,selected ? gold : RGB(28,30,38),selected ? gold : RGB(28,30,38),v->kind==22 ? 6 : 4);
        ink(dc,regular,selected ? background : muted); DrawTextW(dc,text,-1,&r,DT_CENTER|DT_VCENTER|DT_SINGLELINE);
    } else if(v->kind==24) {
        if(v->hover) roundBox(dc,r,RGB(28,30,38),RGB(28,30,38),6);
        RECT title=r; title.right-=px(22); ink(dc,regular,gold); DrawTextW(dc,text,-1,&title,DT_CENTER|DT_VCENTER|DT_SINGLELINE|DT_END_ELLIPSIS);
        RECT arrow=r; arrow.left=arrow.right-px(20); HFONT symbol=CreateFontW(-px(13),0,0,0,FW_NORMAL,0,0,0,DEFAULT_CHARSET,0,0,CLEARTYPE_QUALITY,0,L"Segoe UI Symbol");
        ink(dc,symbol,gold); DrawTextW(dc,L"⌄",-1,&arrow,DT_CENTER|DT_VCENTER|DT_SINGLELINE); SelectObject(dc,regular); DeleteObject(symbol);
    } else if(v->kind==11) {
        if(r.bottom-r.top<px(130)) {
            roundBox(dc,r,foreground,foreground,18);
            RECT category=r; category.left+=px(14); category.top+=px(8); category.bottom=category.top+px(18);
            ink(dc,smallFont,RGB(94,89,79)); DrawTextW(dc,v->category,-1,&category,DT_SINGLELINE);
            RECT title=r; title.left+=px(14); title.right-=px(10); title.top+=px(32); title.bottom=title.top+px(30);
            HFONT compactTitle=face(16,FW_NORMAL,1); ink(dc,compactTitle,RGB(26,25,22));
            DrawTextW(dc,text,-1,&title,DT_SINGLELINE|DT_END_ELLIPSIS); SelectObject(dc,regular); DeleteObject(compactTitle);
            RECT time=r; time.left+=px(14); time.top=r.bottom-px(24); time.right-=px(35);
            ink(dc,smallFont,RGB(94,89,79)); DrawTextW(dc,v->time,-1,&time,DT_SINGLELINE);
            RestoreDC(dc,saved); return;
        }
        roundBox(dc,r,foreground,foreground,22);
        RECT c=r; InflateRect(&c,-px(14),-px(14));
        ink(dc,smallFont,RGB(94,89,79));
        RECT category=c; category.bottom=category.top+px(18);
        ink(dc,regular,wcscmp(v->category,L"Fasting")==0 ? RGB(154,143,196) : gold);
        RECT symbol=category; symbol.top-=px(2); symbol.bottom=category.top+px(19); DrawTextW(dc,wcscmp(v->category,L"Reading")==0 ? L"▱" : wcscmp(v->category,L"Fasting")==0 ? L"♧" : L"⁙",-1,&symbol,DT_SINGLELINE);
        category.top+=px(24); category.bottom+=px(24); ink(dc,smallFont,RGB(94,89,79)); DrawTextW(dc,v->category,-1,&category,DT_SINGLELINE);
        c.top+=px(48);
        int expanded=r.right-r.left>=px(200); int size=18; HFONT title=NULL; RECT measured;
        do { if(title) { SelectObject(dc,regular); DeleteObject(title); } title=face(size,FW_NORMAL,1); ink(dc,title,RGB(26,25,22)); measured=c;
             DrawTextW(dc,text,-1,&measured,DT_WORDBREAK|DT_CALCRECT); if(expanded || measured.bottom-measured.top<=px(68)) break; --size;
        } while(size>=11);
        RECT titleRect=c; titleRect.bottom=c.top+(!expanded && measured.bottom-measured.top>px(68) ? px(68) : measured.bottom-measured.top);
        DrawTextW(dc,text,-1,&titleRect,DT_WORDBREAK|DT_END_ELLIPSIS);
        SelectObject(dc,regular); DeleteObject(title);
        HFONT prose=face(13,FW_NORMAL,1); ink(dc,prose,RGB(94,89,79));
        ink(dc,smallFont,RGB(94,89,79)); RECT sourceMeasure=c;
        DrawTextW(dc,v->attribution,-1,&sourceMeasure,DT_WORDBREAK|DT_CALCRECT);
        int sourceHeight=sourceMeasure.bottom-sourceMeasure.top;
        if(!expanded && sourceHeight>px(21)) sourceHeight=px(21);
        ink(dc,prose,RGB(94,89,79));
        RECT detail=c; detail.top=titleRect.bottom+px(8); detail.bottom=r.bottom-px(40)-sourceHeight;
        if(r.right-r.left<px(200) && detail.bottom>detail.top+px(64)) detail.bottom=detail.top+px(64);
        DrawTextW(dc,v->summary,-1,&detail,DT_WORDBREAK|DT_END_ELLIPSIS);
        SelectObject(dc,regular); DeleteObject(prose);
        ink(dc,smallFont,RGB(94,89,79));
        RECT attribution=c; attribution.top=r.bottom-px(29)-sourceHeight; attribution.bottom=r.bottom-px(29);
        DrawTextW(dc,v->attribution,-1,&attribution,DT_WORDBREAK|DT_END_ELLIPSIS);
        RECT time=c; time.top=r.bottom-px(28); DrawTextW(dc,v->time,-1,&time,DT_SINGLELINE);
    } else if(v->kind==12) {
        HRGN clip=CreateRoundRectRgn(r.left,r.top,r.right+1,r.bottom+1,px(40),px(40)); SelectClipRgn(dc,clip);
        double progress=1; // Windows artwork is stationary.
        ch_draw_art(dc,v->path,r.left,r.top,r.right-r.left,r.bottom-r.top,v->fx,v->fy,v->flags&1,progress,0);
        RECT source=r; InflateRect(&source,-px(18),-px(18));
        HFONT progressFont=NULL;
        if(v->flags&1) {
            wchar_t attribution[2048]; wcsncpy_s(attribution,2048,v->attribution,_TRUNCATE);
            wchar_t *caption=wcschr(attribution,L'\n'); if(caption) *caption++=0;
            HFONT iconCaptionFont=face(10,FW_NORMAL,0); ink(dc,iconCaptionFont,foreground);
            RECT captionRect=source; captionRect.top=captionRect.bottom-px(28);
            if(caption) DrawTextW(dc,caption,-1,&captionRect,DT_CENTER|DT_WORDBREAK);
            SelectObject(dc,regular); DeleteObject(iconCaptionFont);
            source.bottom=captionRect.top-px(6); source.top=source.bottom-px(20); source.left+=px(40);
            HFONT sourceFont=face(12,FW_NORMAL,0); ink(dc,sourceFont,foreground); DrawTextW(dc,attribution,-1,&source,DT_SINGLELINE|DT_END_ELLIPSIS);
            SelectObject(dc,regular); DeleteObject(sourceFont);
            progressFont=CreateFontW(-px(16),0,0,0,FW_NORMAL,TRUE,0,0,DEFAULT_CHARSET,0,0,CLEARTYPE_QUALITY,0,L"XCharter");
        } else {
            source.top=source.bottom-px(32);
            ink(dc,smallFont,foreground); DrawTextW(dc,v->attribution,-1,&source,DT_WORDBREAK|DT_END_ELLIPSIS);
        }
        RECT quote=source; quote.bottom=source.top-px(6); RECT measured=quote;
        wchar_t quoted[2050]; swprintf_s(quoted,2050,L"%ls%ls",text,v->flags&1 ? L"”" : L"");
        ink(dc,progressFont ? progressFont : reading,foreground); DrawTextW(dc,quoted,-1,&measured,DT_WORDBREAK|DT_CALCRECT);
        quote.top=quote.bottom-(measured.bottom-measured.top); if(quote.top<r.top+px(42)) quote.top=r.top+px(42);
        DrawTextW(dc,quoted,-1,&quote,DT_WORDBREAK);
        if(v->flags&1) {
            RECT opening=quote; opening.left=r.left+px(18); opening.right=opening.left+px(40); opening.top-=px(11);
            HFONT ornament=face(49,FW_NORMAL,1); ink(dc,ornament,gold);
            DrawTextW(dc,L"“",-1,&opening,DT_SINGLELINE); SelectObject(dc,regular); DeleteObject(ornament);
        } else {
            RECT caption=r; caption.left+=px(18); caption.top=quote.top-px(22);
            ink(dc,smallFont,foreground); DrawTextW(dc,L"Sayings of the Church Fathers",-1,&caption,DT_SINGLELINE);
        }
        if(progressFont) { SelectObject(dc,regular); DeleteObject(progressFont); }
        DeleteObject(clip);
    } else if(v->kind==16) {
        int diameter=px(22); RECT circle={r.left,r.top,r.left+diameter,r.top+diameter};
        roundBox(dc,circle,(v->flags&1) ? gold : foreground,RGB(168,138,51),16);
        if(v->flags&1) { ink(dc,smallFont,background); DrawTextW(dc,L"✓",-1,&circle,DT_CENTER|DT_VCENTER|DT_SINGLELINE); }
    } else if(v->kind==17 || v->kind==18) {
        if(v->kind==18 && GetDlgCtrlID(item->hwndItem)>=711 && GetDlgCtrlID(item->hwndItem)<=713) calendarChevron(dc,GetDlgCtrlID(item->hwndItem),r);
        else { ink(dc,v->customFont ? v->customFont : regular,v->kind==17 ? RGB(94,89,79) : v->flags&64 ? muted : gold); DrawTextW(dc,text,-1,&r,GetDlgCtrlID(item->hwndItem)>=19000 && GetDlgCtrlID(item->hwndItem)<20000 ? DT_LEFT|DT_VCENTER|DT_SINGLELINE : DT_CENTER|DT_VCENTER|DT_SINGLELINE); }
    } else {
        COLORREF color=disabled ? RGB(100,97,88) : v->kind==9 ? ((v->flags&1) ? foreground : muted) : gold;
        COLORREF fill=(v->kind==9 && v->flags&1) || v->hover ? RGB(28,30,38) : background;
        BOOL animations=TRUE; SystemParametersInfoW(SPI_GETCLIENTAREAANIMATION,0,&animations,0);
        if(v->kind==9 && v->attentionUntil>GetTickCount64()) {
            double remaining=(v->attentionUntil-GetTickCount64())/1000.0;
            double alpha=animations ? .12+.22*(1+sin((5-remaining)*3.141592653589793*2))/2 : .25;
            fill=RGB((int)(GetRValue(fill)*(1-alpha)+GetRValue(foreground)*alpha),(int)(GetGValue(fill)*(1-alpha)+GetGValue(foreground)*alpha),(int)(GetBValue(fill)*(1-alpha)+GetBValue(foreground)*alpha));
        }
        if(v->kind==10) {
            fill=(v->flags&2) ? RGB(59,52,84) : RGB(26,27,34);
            if(v->flags&1) fill=background;
            roundBox(dc,r,fill,(v->flags&1) ? gold : fill,14);
            color=(v->flags&4) ? gold : (v->flags&8) ? RGB(166,58,56) : foreground;
            RECT letters=r; letters.top+=px(5); letters.bottom=letters.top+px(14); ink(dc,smallFont,muted);
            wchar_t *newline=wcschr(text,L'\n'); if(newline) { *newline=0; DrawTextW(dc,text,-1,&letters,DT_CENTER|DT_SINGLELINE); text[0]=0; wcsncpy_s(text,2048,newline+1,_TRUNCATE); }
            RECT number=r; if(newline) { number.top+=px(20); number.bottom-=px(7); } HFONT numerals=face(newline ? 17 : 13,FW_SEMIBOLD,0); ink(dc,numerals,color); DrawTextW(dc,text,-1,&number,DT_CENTER|DT_VCENTER|DT_SINGLELINE); SelectObject(dc,regular); DeleteObject(numerals);
            if(v->flags&16) { HBRUSH dot=CreateSolidBrush(gold); RECT d={r.left+(r.right-r.left)/2-1,r.bottom-px(7),r.left+(r.right-r.left)/2+2,r.bottom-px(4)}; FillRect(dc,&d,dot); DeleteObject(dot); }
        } else if(v->kind==9 && (v->flags&4096)) {
            if((v->flags&1) || v->hover || v->attentionUntil>GetTickCount64()) roundBox(dc,r,fill,fill,8);
            int iconX=(v->flags&8192) ? (r.left+r.right-px(18))/2 : r.left+px(10);
            sidebarIcon(dc,GetDlgCtrlID(item->hwndItem),iconX,(r.top+r.bottom-px(18))/2,color);
            if(!(v->flags&8192)) { RECT label=r; label.left+=px(42); ink(dc,regular,color); DrawTextW(dc,text,-1,&label,DT_VCENTER|DT_SINGLELINE|DT_END_ELLIPSIS); }
        } else if(v->kind==1 && ((GetDlgCtrlID(item->hwndItem)>=11000 && GetDlgCtrlID(item->hwndItem)<13000))) {
            roundBox(dc,r,v->hover ? RGB(40,36,30) : background,gold,4);
            ink(dc,regular,gold); DrawTextW(dc,text,-1,&r,DT_CENTER|DT_VCENTER|DT_SINGLELINE);
        } else {
            if(v->kind!=9 || (v->flags&1) || v->hover || v->attentionUntil>GetTickCount64()) roundBox(dc,r,fill,v->kind==9 ? fill : line,8);
            RECT label=r; InflateRect(&label,-px(v->kind==9 ? 10 : 4),0); ink(dc,regular,color);
            DrawTextW(dc,text,-1,&label,DT_VCENTER|DT_SINGLELINE|(v->kind==9 ? DT_LEFT : DT_CENTER)|DT_END_ELLIPSIS);
        }
    }
    if(focus && keyboardFocus) { RECT f=r; InflateRect(&f,-3,-3); if(v->kind==6 || v->kind==27) f.right=f.left+px(20); DrawFocusRect(dc,&f); }
    RestoreDC(dc,saved);
}
// Paint each custom surface offscreen so the gradient and text arrive together.
static void drawVisual(DRAWITEMSTRUCT *item) {
    int width=item->rcItem.right-item->rcItem.left,height=item->rcItem.bottom-item->rcItem.top;
    if(width<=0 || height<=0) return;
    HDC memory=CreateCompatibleDC(item->hDC);
    HBITMAP bitmap=CreateCompatibleBitmap(item->hDC,width,height); HGDIOBJ old=SelectObject(memory,bitmap);
    SetViewportOrgEx(memory,-item->rcItem.left,-item->rcItem.top,NULL);
    BitBlt(memory,item->rcItem.left,item->rcItem.top,width,height,item->hDC,item->rcItem.left,item->rcItem.top,SRCCOPY);
    DRAWITEMSTRUCT copy=*item; copy.hDC=memory; drawVisualContent(&copy);
    BitBlt(item->hDC,item->rcItem.left,item->rcItem.top,width,height,memory,item->rcItem.left,item->rcItem.top,SRCCOPY);
    SelectObject(memory,old); DeleteObject(bitmap); DeleteDC(memory);
}
static void movePanelChildren(HWND parent,int dx,int dy) {
    int count=0; for(HWND child=GetWindow(parent,GW_CHILD);child;child=GetWindow(child,GW_HWNDNEXT)) count++;
    HDWP batch=BeginDeferWindowPos(count);
    for(HWND child=GetWindow(parent,GW_CHILD);child;child=GetWindow(child,GW_HWNDNEXT)) {
        RECT r; GetWindowRect(child,&r); MapWindowPoints(NULL,parent,(POINT*)&r,2);
        if(batch) batch=DeferWindowPos(batch,child,NULL,r.left+dx,r.top+dy,0,0,SWP_NOSIZE|SWP_NOZORDER|SWP_NOACTIVATE|SWP_NOREDRAW);
        else SetWindowPos(child,NULL,r.left+dx,r.top+dy,0,0,SWP_NOSIZE|SWP_NOZORDER|SWP_NOACTIVATE|SWP_NOREDRAW);
    }
    if(batch) EndDeferWindowPos(batch);
    RedrawWindow(parent,NULL,NULL,RDW_INVALIDATE|RDW_ERASE|RDW_ALLCHILDREN|RDW_UPDATENOW);
}
// Keep the two native rich readers alive across page and glossary redraws.
// Parking them also preserves native selection/caret ownership until reattachment.
static void parkReader(HWND child) {
    if(!child || !IsWindow(child)) return;
    if(GetFocus()==child || IsChild(child,GetFocus())) SetFocus(window);
    ShowWindow(child,SW_HIDE);
    SetParent(child,readerParking);
}
static void parkReadersIn(HWND parent) {
    for(int i=0;i<2;i++) if(pooledReaders[i] && IsChild(parent,pooledReaders[i])) parkReader(pooledReaders[i]);
}
static int readerKey(HWND hwnd,WPARAM wp) {
    Visual *v=GetPropW(hwnd,L"ChotkiVisual"); if(!v) return 0;
    if(wp==VK_ESCAPE && glossaryPanel) { ch_post(6063,0); return 1; }
    if(wp==VK_RETURN) {
        CHARRANGE selected; SendMessageW(hwnd,EM_EXGETSEL,0,(LPARAM)&selected);
        for(LinkRange *link=v->links;link;link=link->next) if(selected.cpMin>=link->start && selected.cpMin<link->end) { ch_post(-7,link->id); return 1; }
    }
    if(wp==VK_TAB && v->links) {
        CHARRANGE selected; SendMessageW(hwnd,EM_EXGETSEL,0,(LPARAM)&selected);
        LinkRange *best=NULL; int backwards=GetKeyState(VK_SHIFT)<0;
        for(LinkRange *link=v->links;link;link=link->next) {
            if(!backwards && link->start>selected.cpMin && (!best || link->start<best->start)) best=link;
            if(backwards && link->start<selected.cpMin && (!best || link->start>best->start)) best=link;
        }
        if(best) { CHARRANGE range={best->start,best->end}; SendMessageW(hwnd,EM_EXSETSEL,0,(LPARAM)&range); v->suppressScroll++; SendMessageW(hwnd,EM_SCROLLCARET,0,0); v->suppressScroll--; return 1; }
        SetFocus(GetNextDlgTabItem(GetParent(hwnd),hwnd,backwards)); return 1;
    }
    return 0;
}
static void checkReaderEnd(HWND child) {
    Visual *v=GetPropW(child,L"ChotkiVisual");
    if(!v || !v->tracked || !v->scrolled || v->suppressScroll) return;
    RECT viewport; GetClientRect(child,&viewport);
    if(v->ends) {
        for(ReadingRange *range=v->ends;range;range=range->next) {
            if(range->completed) continue;
            POINT last={0,0}; SendMessageW(child,EM_POSFROMCHAR,(WPARAM)&last,range->end);
            // A deliberate scroll may pass a section's end before the queued
            // notification arrives. Collapsed sections have no tracked range.
            if(last.y<viewport.bottom) { range->completed=1; ch_post(-6,range->token); }
        }
        return;
    }
    if(v->completed) return;
    GETTEXTLENGTHEX length={GTL_NUMCHARS|GTL_PRECISE,1200};
    LONG count=(LONG)SendMessageW(child,EM_GETTEXTLENGTHEX,(WPARAM)&length,0);
    POINT last={0,0};
    SendMessageW(child,EM_POSFROMCHAR,(WPARAM)&last,count>0 ? count-1 : 0);
    if(count>0 && last.y>=0 && last.y<viewport.bottom) { v->completed=1; ch_post(-6,v->token); }
}
static LRESULT CALLBACK visualProcedure(HWND hwnd,UINT msg,WPARAM wp,LPARAM lp) {
    Visual *v=GetPropW(hwnd,L"ChotkiVisual"); if(!v) return DefWindowProcW(hwnd,msg,wp,lp);
    WNDPROC previous=v->previous;
    if(v->nativePaint && (msg==WM_PAINT || msg==WM_PRINTCLIENT || msg==WM_PRINT)) return CallWindowProcW(previous,hwnd,msg,wp,lp);
    if(v->kind==19 && msg==WM_ERASEBKGND) return 1;
    if(v->kind==19 && (msg==WM_PAINT || msg==WM_PRINTCLIENT)) {
        v->paintCount++;
        RECT r; GetClientRect(hwnd,&r);
        HDC source=GetDC(hwnd); FillRect(source,&r,ground);
        // This Rich Edit version paints its active native view, rather than
        // honoring an arbitrary print DC. Preserve that native paint first,
        // then replace only its solid background with the app gradient.
        v->nativePaint=1; InvalidateRect(hwnd,NULL,FALSE);
        CallWindowProcW(previous,hwnd,WM_PAINT,0,0); v->nativePaint=0;
        HDC memory=CreateCompatibleDC(source); HBITMAP bitmap=CreateCompatibleBitmap(source,max(1,r.right),max(1,r.bottom));
        HGDIOBJ old=SelectObject(memory,bitmap); BitBlt(memory,0,0,r.right,r.bottom,source,0,0,SRCCOPY);
        HDC dc=msg==WM_PAINT ? source : (HDC)wp; int saved=SaveDC(dc);
        IntersectClipRect(dc,0,0,r.right,r.bottom); backdrop(dc,hwnd);
        TransparentBlt(dc,0,0,r.right,r.bottom,memory,0,0,r.right,r.bottom,background);
        if(v->flags&32768) {
            HPEN divider=CreatePen(PS_SOLID,1,line),oldPen=SelectObject(dc,divider);
            for(LinkRange *link=v->links;link;link=link->next) if(link->disclosure) {
                POINT position={0,0}; SendMessageW(hwnd,EM_POSFROMCHAR,(WPARAM)&position,link->start);
                int y=position.y-px(8);
                if(y>=0 && y<r.bottom) { MoveToEx(dc,0,y,NULL); LineTo(dc,r.right-px(2),y); }
            }
            SelectObject(dc,oldPen); DeleteObject(divider);
        }
        RestoreDC(dc,saved); SelectObject(memory,old); DeleteObject(bitmap); DeleteDC(memory); ReleaseDC(hwnd,source); return 0;
    }
    if(msg==WM_LBUTTONDOWN) keyboardFocus=0;
    if(msg==WM_ERASEBKGND && v->kind!=3 && v->kind!=8 && v->kind!=4 && v->kind!=2) return 1;
    if(msg==WM_MOUSEWHEEL && GetDlgCtrlID(hwnd)>=800 && GetDlgCtrlID(hwnd)<=841) { ch_post(-11,GET_WHEEL_DELTA_WPARAM(wp)>0 ? -1 : 1); return 0; }
    if(msg==WM_KEYDOWN && wp=='A' && GetKeyState(VK_CONTROL)<0 && (v->kind==3 || v->kind==8)) {
        SendMessageW(hwnd,EM_SETSEL,0,-1); return 0;
    }
    if(msg==WM_KEYDOWN && wp==VK_ESCAPE && glossaryPanel) { ch_command(6063); return 0; }
    if(msg==WM_MOUSEMOVE && !v->hover) { v->hover=1; TRACKMOUSEEVENT track={sizeof(track),TME_LEAVE,hwnd,0}; TrackMouseEvent(&track); InvalidateRect(hwnd,NULL,FALSE); }
    if(msg==WM_MOUSEMOVE || msg==WM_MOUSELEAVE) { POINT pointer; GetCursorPos(&pointer); updateLibraryHover(pointer); }
    if(msg==WM_MOUSELEAVE) { v->hover=0; InvalidateRect(hwnd,NULL,FALSE); }
    if(msg==WM_MOUSEWHEEL && GetParent(hwnd)!=window && v->kind!=19) return SendMessageW(GetParent(hwnd),msg,wp,lp);
    if(msg==WM_MOUSEWHEEL && v->kind==19) {
        int before=(int)SendMessageW(hwnd,EM_GETFIRSTVISIBLELINE,0,0);
        v->wheelRemainder+=GET_WHEEL_DELTA_WPARAM(wp);
        int lines=v->wheelRemainder/(WHEEL_DELTA/3);
        v->wheelRemainder%=WHEEL_DELTA/3;
        if(lines) {
            int atTop=before==0 && lines>0;
            GETTEXTLENGTHEX options={GTL_NUMCHARS|GTL_PRECISE,1200};
            LONG count=(LONG)SendMessageW(hwnd,EM_GETTEXTLENGTHEX,(WPARAM)&options,0);
            POINT last={0,0}; RECT viewport; GetClientRect(hwnd,&viewport);
            if(count>0) SendMessageW(hwnd,EM_POSFROMCHAR,(WPARAM)&last,count-1);
            int totalLines=(int)SendMessageW(hwnd,EM_GETLINECOUNT,0,0);
            // Rich Edit can report a negative position for the final paragraph
            // mark even when the viewport is already at its last line.
            int atBottom=count==0 || before>=totalLines-1 || (last.y>=0 && last.y<viewport.bottom);
            if(!atTop && !(atBottom && lines<0)) SendMessageW(hwnd,EM_LINESCROLL,0,-lines);
        }
        int after=(int)SendMessageW(hwnd,EM_GETFIRSTVISIBLELINE,0,0);
        if(after!=before) {
            if(v->tracked && !v->suppressScroll) { v->scrolled=1; PostMessageW(window,WM_APP+11,(WPARAM)hwnd,0); }
            InvalidateRect(hwnd,NULL,FALSE);
        }
        return 0;
    }
    if((v->kind==0 || v->kind==5 || v->kind==25 || v->kind==27 || v->kind==6 || v->kind==7 || v->kind==12 || v->kind==20 || v->kind==26) && (msg==WM_PAINT || msg==WM_PRINTCLIENT)) {
        PAINTSTRUCT paint; HDC dc=msg==WM_PAINT ? BeginPaint(hwnd,&paint) : (HDC)wp;
        DRAWITEMSTRUCT item={0}; item.itemID=(UINT)-1; item.hwndItem=hwnd; item.hDC=dc; GetClientRect(hwnd,&item.rcItem); if(GetFocus()==hwnd) item.itemState|=ODS_FOCUS;
        drawVisual(&item); if(msg==WM_PAINT) EndPaint(hwnd,&paint); return 0;
    }
    if(msg==WM_NCDESTROY) {
        LRESULT result=CallWindowProcW(previous,hwnd,msg,wp,lp);
        RemovePropW(hwnd,L"ChotkiVisual");
        while(v->links) { LinkRange *next=v->links->next; free(v->links); v->links=next; }
        while(v->ends) { ReadingRange *next=v->ends->next; free(v->ends); v->ends=next; }
        freeChoices(v); if(v->customFont) DeleteObject(v->customFont);
        free(v->summary); free(v->category); free(v->time); free(v->attribution); free(v->path); free(v);
        return result;
    }
    int userScroll=v->kind!=19 && v->tracked && (msg==WM_MOUSEWHEEL || (msg==WM_VSCROLL && LOWORD(wp)!=SB_ENDSCROLL) ||
                   (msg==WM_KEYDOWN && (wp==VK_NEXT || wp==VK_PRIOR || wp==VK_DOWN || wp==VK_UP)));
    if(userScroll) v->scrolled=1;
    LRESULT result=CallWindowProcW(previous,hwnd,msg,wp,lp);
    if(v->kind==19 && (msg==WM_VSCROLL || msg==WM_MOUSEWHEEL || msg==EM_LINESCROLL || msg==EM_SETSCROLLPOS)) InvalidateRect(hwnd,NULL,FALSE);
    if(userScroll && v->scrolled && !v->completed) {
        SCROLLINFO si={sizeof(si),SIF_ALL}; GetScrollInfo(hwnd,SB_VERT,&si);
        int atEnd=si.nPos+(int)si.nPage-1>=si.nMax || si.nMax==0;
        if(atEnd) { v->completed=1; ch_post(-6,v->token); }
    }
    return result;
}
static LRESULT CALLBACK scrollProcedure(HWND hwnd,UINT msg,WPARAM wp,LPARAM lp) {
    if(msg==WM_MOUSEMOVE || msg==WM_MOUSELEAVE) {
        if(msg==WM_MOUSEMOVE && hwnd==homePanel && libraryHoverCount) { TRACKMOUSEEVENT track={sizeof(track),TME_LEAVE,hwnd,0}; TrackMouseEvent(&track); }
        POINT pointer; GetCursorPos(&pointer); updateLibraryHover(pointer);
    }
    if(msg==WM_NOTIFY || msg==WM_DRAWITEM || msg==WM_COMMAND || msg==WM_CONTEXTMENU || msg==WM_CTLCOLORSTATIC || msg==WM_CTLCOLOREDIT || msg==WM_CTLCOLORLISTBOX || msg==WM_CTLCOLORBTN) return SendMessageW(window,msg,wp,lp);
    if(msg==WM_ERASEBKGND) { backdrop((HDC)wp,hwnd); return 1; }
    if(msg==WM_VSCROLL || msg==WM_HSCROLL || msg==WM_MOUSEWHEEL) {
        int bar=hwnd==cardPanel ? SB_HORZ : SB_VERT;
        SCROLLINFO si={sizeof(si),SIF_ALL}; GetScrollInfo(hwnd,bar,&si); int old=si.nPos;
        if(msg==WM_MOUSEWHEEL) si.nPos-=GET_WHEEL_DELTA_WPARAM(wp)/WHEEL_DELTA*px(48);
        else switch(LOWORD(wp)) { case SB_LINELEFT: si.nPos-=px(24); break; case SB_LINERIGHT: si.nPos+=px(24); break; case SB_PAGELEFT: si.nPos-=si.nPage; break; case SB_PAGERIGHT: si.nPos+=si.nPage; break; case SB_THUMBTRACK: si.nPos=si.nTrackPos; break; case SB_TOP: si.nPos=si.nMin; break; case SB_BOTTOM: si.nPos=si.nMax; break; }
        si.fMask=SIF_POS; SetScrollInfo(hwnd,bar,&si,TRUE); GetScrollInfo(hwnd,bar,&si);
        ShowScrollBar(hwnd,bar,FALSE);
        if(bar==SB_HORZ) cardScroll=si.nPos; else homeScroll=si.nPos;
        if(si.nPos==old) return 0;
        movePanelChildren(hwnd,bar==SB_HORZ ? old-si.nPos : 0,bar==SB_VERT ? old-si.nPos : 0);
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
extern int ch_tray_attach(void *owner, int automation);
extern void ch_tray_detach(void);
extern int ch_tray_message(UINT message, WPARAM wp, LPARAM lp);
static LRESULT CALLBACK procedure(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    if(ch_tray_message(msg,wp,lp)) return 0;
    switch (msg) {
    case WM_MOUSEWHEEL: {
        HWND first=findChild(800),last=findChild(806),toggle=findChild(713);
        if(first && last && toggle) {
            wchar_t label[8]={0}; GetWindowTextW(toggle,label,8);
            if(wcscmp(label,L"⌄")==0) {
                RECT a,b; GetWindowRect(first,&a); GetWindowRect(last,&b);
                POINT pointer={(short)LOWORD(lp),(short)HIWORD(lp)};
                if(pointer.x>=a.left-px(16) && pointer.x<=b.right+px(16) && pointer.y>=a.top-px(12) && pointer.y<=a.bottom+px(12)) {
                    ch_post(-11,GET_WHEEL_DELTA_WPARAM(wp)>0 ? -1 : 1); return 0;
                }
            }
        }
        break;
    }
    case WM_APP+11: checkReaderEnd((HWND)wp); return 0;
    case WM_APP+10: if(callback) callback(context,(int32_t)wp,(int32_t)lp); return 0;
    case WM_SIZE: if(ch_opening_active()) { ch_opening_resize(hwnd); return 0; } if(callback && currentParent && wp!=SIZE_MINIMIZED) callback(context,-4,0); return 0;
    case WM_DPICHANGED: { dpi=HIWORD(wp); fonts(); RECT *r=(RECT*)lp; SetWindowPos(hwnd,NULL,r->left,r->top,r->right-r->left,r->bottom-r->top,SWP_NOZORDER|SWP_NOACTIVATE); return 0; }
    case WM_MEASUREITEM: {
        MEASUREITEMSTRUCT *item=(MEASUREITEMSTRUCT*)lp;
        if(item->CtlType==ODT_MENU) { MenuVisual *v=(MenuVisual*)item->itemData; if(!v) return FALSE;
            HDC dc=GetDC(hwnd); HGDIOBJ old=SelectObject(dc,regular); SIZE size; GetTextExtentPoint32W(dc,v->text,(int)wcslen(v->text),&size); SelectObject(dc,old); ReleaseDC(hwnd,dc);
            item->itemWidth=size.cx+px(64); item->itemHeight=px(v->separator ? 9 : 32); return TRUE;
        } break;
    }
    case WM_DRAWITEM: if(((DRAWITEMSTRUCT*)lp)->CtlType==ODT_MENU) drawMenu((DRAWITEMSTRUCT*)lp); else drawVisual((DRAWITEMSTRUCT*)lp); return TRUE;
    case WM_APP+50: return lifecycleReview ? ch_opening_state() : -1;
    case WM_APP+12: ch_post(CH_TRAY_OPEN,0); return 0;
    case WM_TIMER:
        if(wp==4) { KillTimer(hwnd,4); ch_post(-12,0); return 0; }
        if(wp==3) { ch_post(-9,0); return 0; }
        if(wp==2) {
            int active=0;
            for(int i=0;i<3;i++) { HWND child=findChild(i==0 ? 100 : i==1 ? 102 : 103); Visual *v=GetPropW(child,L"ChotkiVisual"); if(v && v->attentionUntil) { InvalidateRect(child,NULL,FALSE); if(v->attentionUntil>GetTickCount64()) active=1; else v->attentionUntil=0; } }
            if(!active) KillTimer(hwnd,2); return 0;
        }
        if (wp==1 && callback) callback(context,-2,0);
        return 0;
    case WM_ACTIVATEAPP:
        if(ch_opening_active()) return 0;
        if (wp && callback && window) callback(context,-2,0);
        break;
    case WM_POWERBROADCAST:
        if (wp==PBT_APMRESUMEAUTOMATIC && callback) callback(context,-2,0);
        return TRUE;
    case WM_NOTIFY: {
        NMHDR *header=(NMHDR*)lp;
        if(header->code==EN_REQUESTRESIZE) {
            Visual *v=GetPropW(header->hwndFrom,L"ChotkiVisual");
            if(v) v->contentHeight=((REQRESIZE*)lp)->rc.bottom-((REQRESIZE*)lp)->rc.top;
            return 0;
        }
        if(header->code==EN_MSGFILTER) {
            MSGFILTER *event=(MSGFILTER*)lp; Visual *v=GetPropW(header->hwndFrom,L"ChotkiVisual");
            if(v && v->kind==19) {
                if(event->msg==WM_KEYDOWN && readerKey(header->hwndFrom,event->wParam)) return 1;
                if(event->msg==WM_LBUTTONUP || event->msg==WM_MOUSEMOVE) {
                    POINTL point={(short)LOWORD(event->lParam),(short)HIWORD(event->lParam)};
                    LONG position=(LONG)SendMessageW(header->hwndFrom,EM_CHARFROMPOS,0,(LPARAM)&point);
                    for(LinkRange *link=v->links;link;link=link->next) if(position>=link->start && position<link->end) {
                        if(event->msg==WM_LBUTTONUP) { ch_post(-7,link->id); return 1; }
                        SetCursor(LoadCursorW(NULL,IDC_HAND)); return 1;
                    }
                }
                if(v->tracked && (event->msg==WM_MOUSEWHEEL || (event->msg==WM_KEYDOWN &&
                   (event->wParam==VK_NEXT || event->wParam==VK_PRIOR || event->wParam==VK_DOWN || event->wParam==VK_UP)))) {
                    v->scrolled=1; PostMessageW(window,WM_APP+11,(WPARAM)header->hwndFrom,0);
                }
            }
            return 0;
        }
        if(header->code==EN_LINK) {
            ENLINK *event=(ENLINK*)lp; Visual *v=GetPropW(header->hwndFrom,L"ChotkiVisual");
            if(event->msg==WM_LBUTTONUP && v) for(LinkRange *link=v->links;link;link=link->next) {
                if(event->chrg.cpMin==link->start && event->chrg.cpMax==link->end) { ch_post(-7,link->id); return 1; }
            }
        }
        break;
    }
    case WM_COMMAND: {
        Visual *v=GetPropW((HWND)lp,L"ChotkiVisual");
        if(v && v->kind==19) {
            if(HIWORD(wp)==EN_VSCROLL && v->tracked && !v->suppressScroll) {
                v->scrolled=1; PostMessageW(window,WM_APP+11,lp,0);
            }
            return 0;
        }
        // Native controls may still be using their own state after sending
        // WM_COMMAND. Rebuild pages only once that native procedure returns.
        ch_post(LOWORD(wp),HIWORD(wp));
        return 0;
    }
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
        if(v && (v->kind==0 || v->kind==5 || v->kind==25)) { SetBkMode((HDC)wp,TRANSPARENT); return (LRESULT)GetStockObject(NULL_BRUSH); }
        return (LRESULT)ground;
    case WM_ERASEBKGND: {
        backdrop((HDC)wp,hwnd); return 1;
    }
    case WM_CLOSE:
        if(ch_tray_present()) { ShowWindow(hwnd,SW_HIDE); return 0; }
        break;
    case WM_DESTROY: ch_tray_detach(); InterlockedExchangePointer(&postWindow,NULL); PostQuitMessage(exitCode); return 0;
    }
    return DefWindowProcW(hwnd, msg, wp, lp);
}
static wchar_t *priorReadingText;
static int priorReadingLine;
void ch_calendar_browse(int32_t active) { KillTimer(window,4); if(active) SetTimer(window,4,30000,NULL); }
void ch_render_begin(void) {
    if(renderDepth++==0) {
        // Hold child painting only while this synchronous Win32 tree is
        // rebuilt. The main window remains visible to the taskbar.
        renderLocked=IsWindowVisible(window) && LockWindowUpdate(window);
    }
}
void ch_render_end(void) {
    if(renderDepth<=0 || --renderDepth) return;
    if(renderLocked) { LockWindowUpdate(NULL); renderLocked=0; }
    if(IsWindowVisible(window)) RedrawWindow(window,NULL,NULL,RDW_INVALIDATE|RDW_ERASE|RDW_ALLCHILDREN|RDW_UPDATENOW);
}
void ch_clear(void) {
    libraryHoverCount=0;
    prayerKeys=0;
    free(priorReadingText); priorReadingText=NULL; priorReadingLine=0;
    HWND reader=findChild(301);
    if(reader) { int n=GetWindowTextLengthW(reader); priorReadingText=calloc(n+1,sizeof(wchar_t)); GetWindowTextW(reader,priorReadingText,n+1); priorReadingLine=(int)SendMessageW(reader,EM_GETFIRSTVISIBLELINE,0,0); }
    HWND focus=GetFocus(); priorFocus=focus ? GetDlgCtrlID(focus) : 0;
    // End native caret/selection activity while the reader is still alive.
    if(focus && IsChild(window,focus)) SetFocus(window);
    ch_glossary_close();
    parkReadersIn(window);
    // Destroy only owned top-level controls. Windows disposes their internal
    // children; recursively enumerating them can tear down Rich Edit internals.
    HWND child;
    while((child=GetWindow(window,GW_CHILD))!=NULL) DestroyWindow(child);
    homePanel=NULL; cardPanel=NULL; currentParent=window;
    InvalidateRect(window,NULL,TRUE);
}
static int sameReaderText(const wchar_t *a,const wchar_t *b) {
    while(*a && *b) {
        wchar_t ca=*a++,cb=*b++;
        if(ca==L'\r') { if(*a==L'\n') a++; ca=L'\n'; }
        if(cb==L'\r') { if(*b==L'\n') b++; cb=L'\n'; }
        if(ca!=cb) return 0;
    }
    return !*a && !*b;
}
void ch_control(int32_t id, int32_t kind, const char *text, int32_t x, int32_t y, int32_t width, int32_t height) {
    // 6 checkbox, 7 choice, 8 editable multiline; other kinds defined in Swift.
    const wchar_t *cls = (kind==1 || kind==6 || (kind>=9 && kind<=11) || kind==16 || kind==17 || kind==18 || kind==22 || kind==23 || kind==24 || kind==27 || kind==28) ? L"BUTTON" : kind==7 ? L"COMBOBOX" : kind == 2 ? L"LISTBOX" : kind == 19 ? L"RichEdit20W" : (kind == 3 || kind == 4 || kind==8) ? L"EDIT" : L"STATIC";
    DWORD style = WS_CHILD | WS_VISIBLE | WS_CLIPSIBLINGS;
    if (kind == 1 || (kind>=9 && kind<=11) || kind==16 || kind==17 || kind==18 || kind==22 || kind==23 || kind==24 || kind==28) style |= WS_TABSTOP | BS_OWNERDRAW;
    if(kind==27) style |= WS_TABSTOP | BS_AUTOCHECKBOX | BS_MULTILINE;
    if (kind == 2) style |= WS_TABSTOP | LBS_NOTIFY | LBS_NOINTEGRALHEIGHT;
    if (kind == 3) style |= WS_TABSTOP | ES_AUTOHSCROLL | WS_BORDER;
    if (kind == 4 || kind == 19) style |= WS_TABSTOP | ES_MULTILINE | ES_READONLY | ES_AUTOVSCROLL;
    if (kind==25) style |= SS_CENTER;
    if (kind == 12 || kind==20 || kind==26) style |= SS_OWNERDRAW;
    if (kind == 6) style |= WS_TABSTOP | BS_AUTOCHECKBOX | BS_MULTILINE;
    if (kind == 7) style |= WS_TABSTOP | WS_VSCROLL | CBS_DROPDOWNLIST | CBS_OWNERDRAWFIXED | CBS_HASSTRINGS;
    if (kind == 8) style |= WS_TABSTOP | ES_MULTILINE | ES_AUTOVSCROLL | WS_BORDER;
    wchar_t *value = wide(text);
    HWND parent=currentParent ? currentParent : window;
    int offsetX=parent==cardPanel ? cardScroll : 0, offsetY=parent==homePanel ? homeScroll : 0;
    int poolIndex=id==301 ? 0 : id==6014 ? 1 : -1;
    HWND child=kind==19 && poolIndex>=0 ? pooledReaders[poolIndex] : kind==19 && id==7014 ? GetDlgItem(reportWindow,7014) : NULL;
    int reused=child && IsWindow(child);
    if(reused) {
        SetParent(child,parent); EnableWindow(child,TRUE);
        SetWindowLongPtrW(child,GWL_STYLE,style);
        // A pooled reader returns above newly created decoration, as a fresh
        // reader would. Otherwise an overlapping ornament hides its text.
        SetWindowPos(child,HWND_TOP,px(x)-offsetX,px(y)-offsetY,px(width),px(height),SWP_NOACTIVATE|SWP_FRAMECHANGED);
        ShowWindow(child,SW_SHOW);
    } else {
        child=CreateWindowExW(0,cls,kind==19 ? L"" : value,style,px(x)-offsetX,px(y)-offsetY,px(width),px(kind==7 ? height+240 : height),parent,(HMENU)(INT_PTR)id,GetModuleHandleW(NULL),NULL);
        // Match drawing order and hit testing: later controls overlay earlier
        // surfaces, including the separate card completion/expand buttons.
        if(child) SetWindowPos(child,HWND_TOP,0,0,0,0,SWP_NOMOVE|SWP_NOSIZE|SWP_NOACTIVATE);
        if(kind==19 && poolIndex>=0) pooledReaders[poolIndex]=child;
    }
    int restoreReading=child && id==301 && (kind==4 || kind==19) && priorReadingText && sameReaderText(value,priorReadingText);
    if (child) {
        Visual *v=reused ? GetPropW(child,L"ChotkiVisual") : calloc(1,sizeof(Visual));
        if(!reused) {
            v->kind=kind; v->serial=(kind==19 || kind==24 || kind==27) ? ++readerSerial : 0;
            SetPropW(child,L"ChotkiVisual",v);
            v->previous=(WNDPROC)SetWindowLongPtrW(child,GWLP_WNDPROC,(LONG_PTR)visualProcedure);
        }
        while(v->links) { LinkRange *next=v->links->next; free(v->links); v->links=next; }
        while(v->ends) { ReadingRange *next=v->ends->next; free(v->ends); v->ends=next; }
        v->tracked=v->scrolled=v->completed=v->token=v->contentHeight=v->wheelRemainder=0;
        v->restoreLine=restoreReading ? priorReadingLine : 0;
        SendMessageW(child, WM_SETFONT, (WPARAM)(kind == 5 ? heading : (kind == 4 || kind==19) ? reading : regular), TRUE);
        if(kind==19) {
            SendMessageW(child,EM_EXLIMITTEXT,0,1048576); SetWindowTextW(child,value);
            SendMessageW(child,EM_SETBKGNDCOLOR,0,background);
            SendMessageW(child,EM_SETEVENTMASK,0,ENM_LINK|ENM_KEYEVENTS|ENM_MOUSEEVENTS|ENM_SCROLLEVENTS|ENM_SCROLL);
            SendMessageW(child,EM_SETEDITSTYLE,SES_NOFOCUSLINKNOTIFY,SES_NOFOCUSLINKNOTIFY);
            ch_rich_style(id,0,-1,0,18,-1); ch_rich_finish(id); }
        if(id==6060) SendMessageW(child,EM_SETCUEBANNER,TRUE,(LPARAM)L"Search terms");
        if(kind==4 && restoreReading) SendMessageW(child,EM_LINESCROLL,0,priorReadingLine);
        if(id==priorFocus) SetFocus(child);
    }
    if(kind==7) { SendMessageW(child,CB_SETITEMHEIGHT,(WPARAM)-1,px(26)); SendMessageW(child,CB_SETITEMHEIGHT,0,px(30)); }
    free(value);
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
int32_t ch_selected(int32_t id) { Visual *v=GetPropW(findChild(id),L"ChotkiVisual"); if(v && v->kind==24) return v->choice; if(id==300 && cardPanel) return selectedCard; return (int32_t)SendMessageW(findChild(id), isChoice(id) ? CB_GETCURSEL : LB_GETCURSEL, 0, 0); }
void ch_select(int32_t id, int32_t index) { Visual *v=GetPropW(findChild(id),L"ChotkiVisual"); if(v && v->kind==24) { v->choice=index; return; } if(id==300 && cardPanel) { selectedCard=index; return; } SendMessageW(findChild(id), isChoice(id) ? CB_SETCURSEL : LB_SETCURSEL, index, 0); }
void ch_choose(int32_t id, int32_t index) {
    ch_select(id,index); SendMessageW(window,WM_COMMAND,MAKEWPARAM(id,1),(LPARAM)findChild(id));
    if(automation) ch_pump();
}
int32_t ch_checked(int32_t id) { HWND child=findChild(id); Visual *v=GetPropW(child,L"ChotkiVisual"); return SendMessageW(child,BM_GETCHECK,0,0)==BST_CHECKED; }
void ch_check(int32_t id, int32_t checked) { HWND child=findChild(id); SendMessageW(child,BM_SETCHECK,checked ? BST_CHECKED : BST_UNCHECKED,0); InvalidateRect(child,NULL,FALSE); }
void ch_enable(int32_t id, int32_t enabled) { EnableWindow(findChild(id),enabled); }
void ch_command(int32_t id) { SendMessageW(window,WM_COMMAND,MAKEWPARAM(id,0),0); }
void ch_rule_menu(int32_t paused, int32_t dispensed, int32_t kept, int32_t expanded, int32_t about, const char *destination) {
    HMENU menu=CreatePopupMenu(), removal=CreatePopupMenu();
    if(!dispensed) {
        wchar_t *label=wide(destination); AppendMenuW(menu,MF_STRING,456,label); free(label);
        AppendMenuW(menu,MF_STRING,457,expanded ? L"Collapse Card" : L"Expand Card");
        AppendMenuW(menu,MF_SEPARATOR,0,NULL);
        AppendMenuW(menu,MF_STRING,kept ? 452 : 450,kept ? L"Clear This Day" : L"Mark as Kept");
        if(!kept) AppendMenuW(menu,MF_STRING,451,L"Mark as Kept, Late");
        AppendMenuW(menu,MF_STRING,453,L"Stand Down for This Day");
    } else AppendMenuW(menu,MF_STRING|MF_GRAYED,0,L"Lifted by the Church Today");
    if(about) AppendMenuW(menu,MF_STRING,458,L"About This Rule");
    AppendMenuW(menu,MF_SEPARATOR,0,NULL); AppendMenuW(menu,MF_STRING,454,L"Edit Rule…");
    AppendMenuW(menu,MF_STRING,455,paused ? L"Resume This Rule" : L"Pause This Rule");
    AppendMenuW(removal,MF_STRING,460,L"Just this day");
    AppendMenuW(removal,MF_STRING,461,L"This day and after");
    AppendMenuW(removal,MF_STRING,462,L"The whole rule");
    AppendMenuW(menu,MF_POPUP,(UINT_PTR)removal,L"Remove");
    POINT point; GetCursorPos(&point);
    ch_menu_style(menu);
    UINT selected=TrackPopupMenu(menu,TPM_RETURNCMD | TPM_RIGHTBUTTON,point.x,point.y,0,window,NULL);
    ch_menu_destroy(menu);
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
    SendMessageW(child, BM_CLICK, 0, 0); ch_pump(); return 1;
}
void ch_close(int32_t code) { exitCode = code; parkReadersIn(window); DestroyWindow(window); }
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
static int32_t captureWindow(HWND target,const char *path) {
    if(automation || platformReview) SetWindowPos(target,HWND_TOP,0,0,0,0,SWP_NOMOVE|SWP_NOSIZE|SWP_NOACTIVATE);
    RedrawWindow(target,NULL,NULL,RDW_INVALIDATE | RDW_ALLCHILDREN | RDW_UPDATENOW);
    RECT r; GetClientRect(target,&r); int width=r.right, height=r.bottom;
    BITMAPINFO info; ZeroMemory(&info,sizeof(info));
    info.bmiHeader.biSize=sizeof(BITMAPINFOHEADER); info.bmiHeader.biWidth=width; info.bmiHeader.biHeight=height;
    info.bmiHeader.biPlanes=1; info.bmiHeader.biBitCount=32; info.bmiHeader.biCompression=BI_RGB;
    HDC screen=GetDC(target), memory=CreateCompatibleDC(screen); void *pixels=NULL;
    HBITMAP bitmap=CreateDIBSection(screen,&info,DIB_RGB_COLORS,&pixels,NULL,0);
    HGDIOBJ old=SelectObject(memory,bitmap);
    // Capture the visible synthetic client after repainting. PrintWindow can
    // omit transparent Rich Edit content and hid the stale-font defect.
    int ok=BitBlt(memory,0,0,width,height,screen,0,0,SRCCOPY);
    if(target==window && ch_opening_active()) ch_opening_paint(memory);
    GdiFlush();
    // A noninteractive SSH desktop can return success with an empty bitmap.
    if(ok) {
        unsigned char *bytes=pixels; int hasColor=0;
        for(int i=0;i<width*height*4;i++) if(bytes[i]) { hasColor=1; break; }
        if(!hasColor) ok=0;
    }
    if (ok) {
        // PrintWindow's GDI output has undefined alpha. Captures are opaque;
        // normalize it so PNG conversion never hides otherwise valid pixels.
        unsigned char *bytes=pixels;
        for(int i=0;i<width*height;i++) bytes[i*4+3]=255;
        BITMAPFILEHEADER file; ZeroMemory(&file,sizeof(file));
        file.bfType=0x4d42; file.bfOffBits=sizeof(file)+sizeof(info.bmiHeader); file.bfSize=file.bfOffBits+width*height*4;
        wchar_t *name=wide(path); HANDLE handle=CreateFileW(name,GENERIC_WRITE,0,NULL,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,NULL); free(name);
        if (handle==INVALID_HANDLE_VALUE) ok=0;
        else { DWORD written; ok=WriteFile(handle,&file,sizeof(file),&written,NULL) && WriteFile(handle,&info.bmiHeader,sizeof(info.bmiHeader),&written,NULL) && WriteFile(handle,pixels,width*height*4,&written,NULL); CloseHandle(handle); }
    }
    SelectObject(memory,old); DeleteObject(bitmap); DeleteDC(memory); ReleaseDC(target,screen); return ok;
}
int32_t ch_capture(const char *path) { return captureWindow(window,path); }
int32_t ch_capture_report(const char *path) { return reportWindow ? captureWindow(reportWindow,path) : 0; }
void ch_post(int32_t control, int32_t event) {
    HWND target=InterlockedCompareExchangePointer(&postWindow,NULL,NULL);
    if(target) PostMessageW(target,WM_APP+10,(WPARAM)(INT_PTR)control,(LPARAM)event);
}
static int ropeSpace(MSG *msg) {
    if((msg->message!=WM_KEYDOWN && msg->message!=WM_KEYUP) || msg->wParam!=VK_SPACE || !prayerKeys || glossaryPanel || !IsWindowVisible(window)) return 0;
    HWND count=findChild(420);
    if(!count || !IsWindowVisible(count) || !IsWindowEnabled(count)) return 0;
    if(GetKeyState(VK_CONTROL)<0 || GetKeyState(VK_MENU)<0 || GetKeyState(VK_SHIFT)<0 || GetKeyState(VK_LWIN)<0 || GetKeyState(VK_RWIN)<0) return 0;
    if(msg->hwnd!=window && msg->hwnd!=count) {
        Visual *v=GetPropW(msg->hwnd,L"ChotkiVisual");
        if(!v || v->kind!=19 || GetDlgCtrlID(msg->hwnd)!=301) return 0;
    }
    if(msg->message==WM_KEYDOWN && !(msg->lParam & (1L<<30))) ch_post(420,0);
    return 1;
}
static void dispatchUI(MSG *msg) {
    if(msg->message==WM_KEYDOWN && msg->wParam==VK_TAB) keyboardFocus=1;
    if(msg->message==WM_LBUTTONDOWN) keyboardFocus=0;
    if(ch_opening_active() && (msg->message==WM_KEYDOWN || msg->message==WM_KEYUP || msg->message==WM_CHAR || msg->message==WM_SYSKEYDOWN || msg->message==WM_SYSKEYUP)) return;

    if(ropeSpace(msg)) return;
    Visual *v=GetPropW(msg->hwnd,L"ChotkiVisual");
    if(msg->message==WM_KEYDOWN && (msg->wParam==VK_TAB || msg->wParam==VK_RETURN) && v && v->links) { TranslateMessage(msg); DispatchMessageW(msg); }
    else if(!IsDialogMessageW(window,msg)) { TranslateMessage(msg); DispatchMessageW(msg); }
}
void ch_pump(void) { MSG msg; while(PeekMessageW(&msg,NULL,0,0,PM_REMOVE)) { if(msg.message==WM_QUIT) { PostQuitMessage((int)msg.wParam); break; } dispatchUI(&msg); } }
int32_t ch_test_space(int32_t id,int32_t repeat) {
    if(!automation) return -1;
    HWND child=id ? findChild(id) : window; if(!child) return -1;
    MSG msg={0}; msg.hwnd=child; msg.message=WM_KEYDOWN; msg.wParam=VK_SPACE; msg.lParam=repeat ? (1L<<30) : 1;
    int consumed=ropeSpace(&msg); ch_pump(); return consumed;
}
int32_t ch_width(void) { RECT r; GetClientRect(window,&r); return MulDiv(r.right,96,dpi); }
int32_t ch_height(void) { RECT r; GetClientRect(window,&r); return MulDiv(r.bottom,96,dpi); }
int32_t ch_font(const char *path) { wchar_t *value=wide(path); int result=AddFontResourceExW(value,FR_PRIVATE,0); free(value); return result; }
int32_t ch_reading_face(char *buffer,int32_t length) {
    HDC dc=GetDC(window); HGDIOBJ old=SelectObject(dc,reading); wchar_t value[128]; GetTextFaceW(dc,128,value);
    SelectObject(dc,old); ReleaseDC(window,dc);
    return WideCharToMultiByte(CP_UTF8,0,value,-1,buffer,length,NULL,NULL);
}
void ch_font_size(int32_t id,int32_t size,int32_t serif,int32_t bold) {
    HWND child=findChild(id); Visual *v=GetPropW(child,L"ChotkiVisual"); if(!v) return;
    HFONT next=face(size,bold ? FW_BOLD : FW_NORMAL,serif!=0),old=v->customFont;
    v->customFont=next; SendMessageW(child,WM_SETFONT,(WPARAM)next,TRUE); if(old) DeleteObject(old);
}
void ch_attention(int32_t id,int32_t milliseconds) {
    HWND child=findChild(id); Visual *v=GetPropW(child,L"ChotkiVisual"); if(!v) return;
    v->attentionUntil=milliseconds>0 ? GetTickCount64()+milliseconds : 0; InvalidateRect(child,NULL,FALSE);
    if(milliseconds>0) { BOOL animations=TRUE; SystemParametersInfoW(SPI_GETCLIENTAREAANIMATION,0,&animations,0); SetTimer(window,2,animations ? 33 : milliseconds,NULL); }
}
int32_t ch_test_attention(int32_t id) { Visual *v=GetPropW(findChild(id),L"ChotkiVisual"); return automation && v && v->attentionUntil>GetTickCount64(); }
void ch_style(int32_t id,int32_t flags) { HWND handle=findChild(id); Visual *v=GetPropW(handle,L"ChotkiVisual"); if(v) { v->flags=flags; if(flags&16384) { v->customFont=CreateFontW(-px(13),0,0,0,FW_NORMAL,TRUE,FALSE,FALSE,DEFAULT_CHARSET,0,0,CLEARTYPE_QUALITY,0,L"Segoe UI"); SendMessageW(handle,WM_SETFONT,(WPARAM)v->customFont,TRUE); } else if(flags&2048) SendMessageW(handle,WM_SETFONT,(WPARAM)listFont,TRUE); else if(flags&256) SendMessageW(handle,WM_SETFONT,(WPARAM)dateFont,TRUE); else if(flags&512) SendMessageW(handle,WM_SETFONT,(WPARAM)smallFont,TRUE); else if(flags&1024) SendMessageW(handle,WM_SETFONT,(WPARAM)captionFont,TRUE); InvalidateRect(handle,NULL,FALSE); } }
int32_t ch_test_space_modifier(int32_t id,int32_t modifier) {
    if(!automation || modifier<0 || modifier>255) return -1;
    BYTE saved[256],state[256]; if(!GetKeyboardState(saved)) return -1;
    memcpy(state,saved,sizeof(state)); state[modifier]|=0x80;
    if(!SetKeyboardState(state)) return -1;
    int result=ch_test_space(id,0); SetKeyboardState(saved); return result;
}
void ch_rope_update(int32_t id,int32_t count,int32_t target) {
    HWND child=findChild(id); Visual *v=GetPropW(child,L"ChotkiVisual"); if(!v) return;
    v->count=count; v->target=target;
    wchar_t description[80]; swprintf_s(description,80,L"%d of %d knots%s",count,target,count>=target ? L", the knot is complete" : L"");
    SetWindowTextW(child,description); InvalidateRect(child,NULL,FALSE);
}
void ch_prayer_keys(int32_t enabled) { prayerKeys=enabled!=0; }
void ch_choice_add(int32_t id,const char *title,const char *group,int32_t index) {
    Visual *v=GetPropW(findChild(id),L"ChotkiVisual"); if(!v || v->kind!=24) return;
    ChoiceItem *item=calloc(1,sizeof(*item)); item->title=wide(title); item->group=wide(group); item->index=index;
    ChoiceItem **tail=&v->choices; while(*tail) tail=&(*tail)->next; *tail=item;
}
static HMENU choiceMenu(Visual *v) {
    HMENU menu=CreatePopupMenu(); const wchar_t *group=L"";
    for(ChoiceItem *item=v->choices;item;item=item->next) {
        if(wcscmp(group,item->group)!=0) {
            AppendMenuW(menu,MF_SEPARATOR,0,NULL); AppendMenuW(menu,MF_STRING|MF_GRAYED,0,item->group); group=item->group;
        }
        AppendMenuW(menu,MF_STRING|(v->choice==item->index ? MF_CHECKED : 0),10000+item->index,item->title);
    }
    return menu;
}
void ch_choice_popup(int32_t id) {
    HWND child=findChild(id); Visual *v=GetPropW(child,L"ChotkiVisual"); if(!v || v->kind!=24) return;
    int serial=v->serial; HMENU menu=choiceMenu(v); RECT r; GetWindowRect(child,&r);
    ch_menu_style(menu);
    UINT selected=TrackPopupMenu(menu,TPM_RETURNCMD|TPM_LEFTALIGN,r.left,r.bottom,0,window,NULL); ch_menu_destroy(menu);
    // A nested menu loop may process a day rollover. Do not use stale state.
    Visual *current=GetPropW(findChild(id),L"ChotkiVisual");
    if(selected>=10000 && current && current->serial==serial) { current->choice=selected-10000; ch_post(id,1); }
}
int32_t ch_test_prayer_menu(int32_t id) {
    if(!automation) return 0; Visual *v=GetPropW(findChild(id),L"ChotkiVisual"); if(!v || !v->choices) return 0;
    HMENU menu=choiceMenu(v); int disabled=0, choices=0;
    for(int i=0;i<GetMenuItemCount(menu);i++) {
        UINT command=GetMenuItemID(menu,i),state=GetMenuState(menu,i,MF_BYPOSITION);
        if(command>=10000 && command!=(UINT)-1) choices++;
        else if(!(state&MF_SEPARATOR) && (state&MF_GRAYED)) disabled++;
    }
    DestroyMenu(menu); return disabled==3 && choices>3;
}
static void panelScroll(HWND handle,int bar,int total,int page,int position) {
    SCROLLINFO si={sizeof(si),SIF_RANGE|SIF_PAGE|SIF_POS,0,px(total)-1,px(page),position,0};
    SetScrollInfo(handle,bar,&si,TRUE); si.fMask=SIF_POS; GetScrollInfo(handle,bar,&si);
    ShowScrollBar(handle,bar,FALSE);
    if(bar==SB_HORZ) cardScroll=si.nPos; else homeScroll=si.nPos;
}
void ch_home_begin(int32_t x,int32_t y,int32_t width,int32_t height,int32_t contentHeight) {
    homePanel=CreateWindowExW(WS_EX_CONTROLPARENT,L"ChotkiScroll",L"The day",WS_CHILD|WS_VISIBLE|WS_CLIPCHILDREN|WS_VSCROLL,
                             px(x),px(y),px(width),px(height),window,(HMENU)9008,GetModuleHandleW(NULL),NULL);
    panelScroll(homePanel,SB_VERT,contentHeight,height,homeScroll); currentParent=homePanel;
}
void ch_home_end(void) { currentParent=window; }
void ch_cards_begin(int32_t x,int32_t y,int32_t width,int32_t height,int32_t contentWidth) {
    cardPanel=CreateWindowExW(WS_EX_CONTROLPARENT,L"ChotkiScroll",L"Today's commitments",WS_CHILD|WS_VISIBLE|WS_CLIPCHILDREN|WS_HSCROLL,
                             px(x),px(y)-homeScroll,px(width),px(height),homePanel,(HMENU)9009,GetModuleHandleW(NULL),NULL);
    panelScroll(cardPanel,SB_HORZ,contentWidth,width,cardScroll); currentParent=cardPanel;
}
void ch_reveal_card(int32_t id) {
    HWND card=findChild(id); if(!card || !cardPanel) return;
    RECT bounds,viewport; GetWindowRect(card,&bounds); MapWindowPoints(NULL,cardPanel,(POINT*)&bounds,2); GetClientRect(cardPanel,&viewport);
    SCROLLINFO si={sizeof(si),SIF_ALL}; GetScrollInfo(cardPanel,SB_HORZ,&si); int previous=si.nPos;
    si.nPos += (bounds.left+bounds.right-viewport.right)/2; si.fMask=SIF_POS;
    SetScrollInfo(cardPanel,SB_HORZ,&si,FALSE); GetScrollInfo(cardPanel,SB_HORZ,&si); cardScroll=si.nPos;
    movePanelChildren(cardPanel,previous-si.nPos,0);
}
int32_t ch_test_card_revealed(int32_t id) {
    if(!automation || !cardPanel) return 0;
    HWND card=findChild(id); RECT bounds,viewport; if(!card) return 0;
    GetWindowRect(card,&bounds); MapWindowPoints(NULL,cardPanel,(POINT*)&bounds,2); GetClientRect(cardPanel,&viewport);
    return bounds.left>=0 && bounds.right<=viewport.right;
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
void ch_opening_show_if_needed(void) { ch_opening_start(window,automation || platformReview); }
int32_t ch_test_opening_frame(double milliseconds) { return automation ? ch_opening_fixture(window,milliseconds) : 0; }
void ch_review_mode(int32_t review) { platformReview=review!=0; }
void ch_start_hidden(int32_t hidden) { startHidden=hidden!=0; }
void ch_lifecycle_review(int32_t enabled) { lifecycleReview=enabled!=0; }
int32_t ch_single_instance(void) {
    instanceMutex=CreateMutexW(NULL,FALSE,lifecycleReview ? L"Local\\Chotki.Windows.LifecycleReview" : L"Local\\Chotki.Windows.Instance");
    if(!instanceMutex || GetLastError()!=ERROR_ALREADY_EXISTS) return 1;
    for(int attempt=0;attempt<40;attempt++) {
        HWND existing=FindWindowW(mainClass(),L"Chotki");
        if(existing) { DWORD owner=0; GetWindowThreadProcessId(existing,&owner); AllowSetForegroundWindow(owner); PostMessageW(existing,WM_APP+12,0,0); CloseHandle(instanceMutex); instanceMutex=NULL; return 0; }
        Sleep(50);
    }
    CloseHandle(instanceMutex); instanceMutex=NULL; return 0;
}
void ch_taskbar(int32_t visible) {
    if(!window) return; LONG_PTR style=GetWindowLongPtrW(window,GWL_EXSTYLE),next=visible ? (style&~WS_EX_TOOLWINDOW)|WS_EX_APPWINDOW : (style&~WS_EX_APPWINDOW)|WS_EX_TOOLWINDOW;
    if(style==next) return;
    BOOL shown=IsWindowVisible(window); if(shown) ShowWindow(window,SW_HIDE);
    SetWindowLongPtrW(window,GWL_EXSTYLE,next); if(shown) ShowWindow(window,SW_SHOWNOACTIVATE);
}
static int syntheticStartup=0;
int32_t ch_startup(int32_t enabled) {
    if(automation || platformReview) { syntheticStartup=enabled!=0; return 0; }
    HKEY key=NULL; LONG result=RegCreateKeyExW(HKEY_CURRENT_USER,lifecycleReview ? L"Software\\Chotki\\LifecycleReview\\Run" : L"Software\\Microsoft\\Windows\\CurrentVersion\\Run",0,NULL,0,KEY_SET_VALUE,NULL,&key,NULL);
    if(result!=ERROR_SUCCESS) return result;
    if(enabled) {
        wchar_t *path=calloc(32768,sizeof(wchar_t)),*command=calloc(32790,sizeof(wchar_t));
        DWORD length=GetModuleFileNameW(NULL,path,32768);
        if(!length || length>=32768) result=ERROR_INSUFFICIENT_BUFFER;
        else {
            wchar_t *slash=wcsrchr(path,L'\\'); wchar_t launcher[32768];
            swprintf_s(launcher,32768,L"%.*s\\launch-windows.ps1",slash ? (int)(slash-path) : 0,path);
            if(GetFileAttributesW(launcher)!=INVALID_FILE_ATTRIBUTES) {
                wchar_t system[MAX_PATH]; GetSystemDirectoryW(system,MAX_PATH);
                // The installed launcher excludes host ARM64 Swift paths.
                swprintf_s(command,32790,L"\"%s\\WindowsPowerShell\\v1.0\\powershell.exe\" -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File \"%s\" -Startup",system,launcher);
            } else swprintf_s(command,32790,L"\"%s\" --startup",path);
            result=RegSetValueExW(key,L"Chotki",0,REG_SZ,(BYTE*)command,(DWORD)((wcslen(command)+1)*sizeof(wchar_t))); }
        free(path); free(command);
    } else { result=RegDeleteValueW(key,L"Chotki"); if(result==ERROR_FILE_NOT_FOUND) result=ERROR_SUCCESS; }
    RegCloseKey(key); return result;
}
int32_t ch_test_startup(void) { return automation ? syntheticStartup : -1; }
int32_t ch_measure_text(const char *text,int32_t width,int32_t flags) {
    wchar_t *value=wide(text); HDC dc=GetDC(window);
    HFONT font=flags&2048 ? listFont : flags&256 ? dateFont : flags&512 ? smallFont : regular;
    HGDIOBJ old=SelectObject(dc,font); RECT rect={0,0,px(width),0};
    DrawTextW(dc,value,-1,&rect,DT_WORDBREAK|DT_CALCRECT|DT_NOPREFIX);
    SelectObject(dc,old); ReleaseDC(window,dc); free(value);
    return (int32_t)ceil((rect.bottom+2)/(dpi/96.0));
}
int32_t ch_measure_reading(const char *text,int32_t width,int32_t size) {
    wchar_t *value=wide(text); HDC dc=GetDC(window); HFONT font=face(size,FW_NORMAL,1);
    HGDIOBJ old=SelectObject(dc,font); RECT rect={0,0,px(width),0};
    DrawTextW(dc,value,-1,&rect,DT_WORDBREAK|DT_CALCRECT|DT_NOPREFIX);
    SelectObject(dc,old); DeleteObject(font); ReleaseDC(window,dc); free(value);
    return (int32_t)ceil((rect.bottom+2)/(dpi/96.0));
}
static LRESULT CALLBACK reportProcedure(HWND hwnd,UINT msg,WPARAM wp,LPARAM lp) {
    if(msg==WM_CLOSE) { ShowWindow(hwnd,SW_HIDE); return 0; }
    if(msg==WM_SIZE) { HWND reader=GetDlgItem(hwnd,7014); if(reader) MoveWindow(reader,px(28),px(28),max(px(100),LOWORD(lp)-px(56)),max(px(100),HIWORD(lp)-px(56)),TRUE); return 0; }
    if(msg==WM_ERASEBKGND) { backdrop((HDC)wp,hwnd); return 1; }
    if(msg==WM_CTLCOLORSTATIC || msg==WM_CTLCOLOREDIT || msg==WM_NOTIFY) return SendMessageW(window,msg,wp,lp);
    return DefWindowProcW(hwnd,msg,wp,lp);
}
int32_t ch_report_begin(void) {
    if(!reportWindow) {
        WNDCLASSW cls={0}; cls.lpfnWndProc=reportProcedure; cls.hInstance=GetModuleHandleW(NULL); cls.hCursor=LoadCursorW(NULL,IDC_ARROW); cls.hbrBackground=ground; cls.lpszClassName=L"ChotkiReport";
        RegisterClassW(&cls); RECT r={0,0,px(620),px(640)}; AdjustWindowRectExForDpi(&r,WS_OVERLAPPEDWINDOW,FALSE,0,dpi);
        reportWindow=CreateWindowExW(0,cls.lpszClassName,L"Progress",WS_OVERLAPPEDWINDOW|WS_CLIPCHILDREN,CW_USEDEFAULT,CW_USEDEFAULT,r.right-r.left,r.bottom-r.top,window,NULL,cls.hInstance,NULL);
        BOOL dark=TRUE; DwmSetWindowAttribute(reportWindow,20,&dark,sizeof(dark));
    }
    if(!reportWindow) return 0;
    // Keep the report reader alive across refreshes, just like the main reader.
    currentParent=reportWindow; RECT r; GetClientRect(reportWindow,&r); return MulDiv(r.right,96,dpi);
}
int32_t ch_report_height(void) { RECT r; GetClientRect(reportWindow,&r); return MulDiv(r.bottom,96,dpi); }
void ch_report_end(int32_t show) { currentParent=window; if(show && reportWindow) { ShowWindow(reportWindow,automation ? SW_SHOWNOACTIVATE : SW_SHOW); if(!automation) SetForegroundWindow(reportWindow); UpdateWindow(reportWindow); } }
int32_t ch_report_visible(void) { return reportWindow && IsWindowVisible(reportWindow); }
int32_t ch_test_report(int32_t operation) {
    if(!automation || !reportWindow) return 0;
    if(operation==0) SendMessageW(reportWindow,WM_CLOSE,0,0);
    return IsWindow(reportWindow);
}
int32_t ch_test_control_intersects(int32_t id) {
    if(!automation) return 0;
    HWND child=findChild(id); if(!child || !IsWindowVisible(child)) return 0;
    RECT visible; GetWindowRect(child,&visible);
    for(HWND parent=GetParent(child);parent;parent=parent==window ? NULL : GetParent(parent)) {
        RECT clip; GetClientRect(parent,&clip); MapWindowPoints(parent,NULL,(POINT*)&clip,2);
        RECT intersection; if(!IntersectRect(&intersection,&visible,&clip)) return 0;
        visible=intersection;
    }
    return visible.bottom-visible.top>=px(90);
}
int32_t ch_test_control_visible(int32_t id) {
    if(!automation) return 0;
    HWND child=findChild(id); if(!child || !IsWindowVisible(child)) return 0;
    RECT bounds; GetWindowRect(child,&bounds);
    for(HWND parent=GetParent(child);parent;parent=parent==window ? NULL : GetParent(parent)) {
        RECT clip; GetClientRect(parent,&clip); MapWindowPoints(parent,NULL,(POINT*)&clip,2);
        if(bounds.left<clip.left || bounds.right>clip.right || bounds.top<clip.top || bounds.bottom>clip.bottom) return 0;
    }
    return 1;
}
void ch_test_calendar_expire(void) { if(automation) { SendMessageW(window,WM_TIMER,4,0); ch_pump(); } }
void ch_test_panel_wheel(int32_t turns) {
    if(!automation || !homePanel) return;
    for(int i=0;i<abs(turns);i++) SendMessageW(homePanel,WM_MOUSEWHEEL,MAKEWPARAM(0,turns>0 ? (short)-WHEEL_DELTA : (short)WHEEL_DELTA),0);
}
int32_t ch_test_reader_first_line(int32_t id) { return automation && findChild(id) ? (int32_t)SendMessageW(findChild(id),EM_GETFIRSTVISIBLELINE,0,0) : -1; }
int32_t ch_test_reader_paint_count(int32_t id) {
    HWND child=findChild(id);
    if(child) UpdateWindow(child);
    Visual *v=GetPropW(child,L"ChotkiVisual");
    return automation && v && v->kind==19 ? v->paintCount : -1;
}
int32_t ch_test_reader_wheel(int32_t id,int32_t turns) {
    HWND child=findChild(id); if(!automation || !child) return -1;
    for(int i=0;i<abs(turns);i++) SendMessageW(child,WM_MOUSEWHEEL,MAKEWPARAM(0,turns>0 ? (short)-WHEEL_DELTA : (short)WHEEL_DELTA),0);
    return (int32_t)SendMessageW(child,EM_GETFIRSTVISIBLELINE,0,0);
}
int32_t ch_test_reader_wheel_delta(int32_t id,int32_t delta,int32_t repeats) {
    HWND child=findChild(id); if(!automation || !child || repeats<0 || repeats>32) return -1;
    for(int i=0;i<repeats;i++) SendMessageW(child,WM_MOUSEWHEEL,MAKEWPARAM(0,(short)delta),0);
    return (int32_t)SendMessageW(child,EM_GETFIRSTVISIBLELINE,0,0);
}
void ch_show(int32_t id,int32_t visible) { HWND child=findChild(id); if(child) ShowWindow(child,visible ? SW_SHOWNA : SW_HIDE); }
void ch_library_hover(int32_t anchor,int32_t firstLink,int32_t count,int32_t height) {
    if(libraryHoverCount>=128) return;
    libraryHovers[libraryHoverCount++]=(LibraryHover){anchor,firstLink,count,height,0};
}
int32_t ch_test_library_hover(int32_t firstLink,int32_t active) {
    if(!automation) return -1;
    POINT pointer={0,0};
    if(active) for(int i=0;i<libraryHoverCount;i++) if(libraryHovers[i].first==firstLink) {
        HWND anchor=findChild(libraryHovers[i].anchor); RECT r;
        if(anchor) { GetWindowRect(anchor,&r); pointer.x=r.left+px(10); pointer.y=r.top+px(10); }
        break;
    }
    updateLibraryHover(pointer);
    HWND link=findChild(firstLink); return link && IsWindowVisible(link);
}
void ch_test_panel_scroll(int32_t bottom) { if(automation && homePanel) SendMessageW(homePanel,WM_VSCROLL,bottom ? SB_BOTTOM : SB_TOP,0); }
void ch_home_content(int32_t height) { if(homePanel) { RECT r; GetClientRect(homePanel,&r); panelScroll(homePanel,SB_VERT,height,MulDiv(r.bottom,96,dpi),homeScroll); } }
int32_t ch_rich_fit(int32_t id) {
    HWND child=findChild(id); Visual *v=GetPropW(child,L"ChotkiVisual"); if(!v || v->kind!=19) return 0;
    v->suppressScroll++;
    RECT r; GetWindowRect(child,&r); POINT origin={r.left,r.top}; ScreenToClient(GetParent(child),&origin);
    LONG_PTR style=GetWindowLongPtrW(child,GWL_STYLE); SetWindowLongPtrW(child,GWL_STYLE,style&~WS_VSCROLL);
    SetWindowPos(child,NULL,0,0,0,0,SWP_NOMOVE|SWP_NOSIZE|SWP_NOZORDER|SWP_NOACTIVATE|SWP_FRAMECHANGED);
    SendMessageW(child,EM_SETEVENTMASK,0,SendMessageW(child,EM_GETEVENTMASK,0,0)|ENM_REQUESTRESIZE);
    SendMessageW(child,EM_REQUESTRESIZE,0,0);
    int height=v->contentHeight+px(6);
    if(height<px(20)) {
        LONG count=GetWindowTextLengthW(child); POINT last={0,0};
        SendMessageW(child,EM_POSFROMCHAR,(WPARAM)&last,count>0 ? count-1 : 0);
        height=max(px(24),last.y+px(28));
    }
    MoveWindow(child,origin.x,origin.y,r.right-r.left,height,TRUE);
    v->suppressScroll--; return MulDiv(height,96,dpi);
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
void ch_track_reading_range(int32_t id,int32_t end,int32_t token) {
    Visual *v=GetPropW(findChild(id),L"ChotkiVisual"); if(!v) return;
    ReadingRange *range=calloc(1,sizeof(*range)); range->end=end; range->token=token;
    range->next=v->ends; v->ends=range; v->tracked=1;
}
void ch_reader_scroll_line(int32_t id,int32_t line) {
    HWND child=findChild(id); Visual *v=GetPropW(child,L"ChotkiVisual"); if(!v) return;
    v->suppressScroll++;
    SendMessageW(child,EM_LINESCROLL,0,line-(int)SendMessageW(child,EM_GETFIRSTVISIBLELINE,0,0));
    v->suppressScroll--;
}
void ch_test_scroll_character(int32_t id,int32_t position,int32_t deliberate) {
    if(!automation) return;
    HWND child=findChild(id); Visual *v=GetPropW(child,L"ChotkiVisual"); if(!v) return;
    CHARRANGE range={position,position}; v->suppressScroll++;
    SendMessageW(child,EM_EXSETSEL,0,(LPARAM)&range);
    int line=(int)SendMessageW(child,EM_EXLINEFROMCHAR,0,position);
    SendMessageW(child,EM_LINESCROLL,0,line-(int)SendMessageW(child,EM_GETFIRSTVISIBLELINE,0,0));
    v->suppressScroll--;
    if(deliberate) { v->scrolled=1; PostMessageW(window,WM_APP+11,(WPARAM)child,0); }
}
void ch_test_scroll_end(int32_t id,int32_t deliberate) {
    if(!automation) return;
    HWND child=findChild(id); Visual *v=GetPropW(child,L"ChotkiVisual");
    if(deliberate) {
        SendMessageW(child,WM_VSCROLL,SB_BOTTOM,0);
        if(v && v->kind==19) { v->scrolled=1; PostMessageW(window,WM_APP+11,(WPARAM)child,0); }
    } else {
        if(v) v->suppressScroll++;
        int lines=(int)SendMessageW(child,EM_GETLINECOUNT,0,0);
        int first=(int)SendMessageW(child,EM_GETFIRSTVISIBLELINE,0,0);
        // Keep synthetic scrolling within the actual document.
        SendMessageW(child,EM_LINESCROLL,0,lines>first ? lines-first-1 : 0);
        if(v) v->suppressScroll--;
    }
}
int32_t ch_run(ChotkiEvent event, void *data, int32_t automated) {
    callback=event; context=data; automation=automated;
    HRESULT oleStatus=OleInitialize(NULL);
    if(FAILED(oleStatus)) return 6;
    SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
    dpi=GetDpiForSystem();
    ground=CreateSolidBrush(background); panel=CreateSolidBrush(RGB(28,30,38));
    fonts();
    richLibrary=LoadLibraryExW(L"Riched20.dll",NULL,LOAD_LIBRARY_SEARCH_SYSTEM32);
    if(!richLibrary) return 5;
    WNDCLASSW cls; ZeroMemory(&cls,sizeof(cls)); cls.lpfnWndProc=procedure; cls.hInstance=GetModuleHandleW(NULL);
    cls.hCursor=LoadCursorW(NULL,IDC_ARROW); cls.hIcon=LoadIconW(cls.hInstance,MAKEINTRESOURCEW(1)); cls.hbrBackground=ground; cls.lpszClassName=mainClass();
    if(!RegisterClassW(&cls)) return 2;
    WNDCLASSW scrollClass; ZeroMemory(&scrollClass,sizeof(scrollClass)); scrollClass.lpfnWndProc=scrollProcedure; scrollClass.hInstance=cls.hInstance; scrollClass.hCursor=cls.hCursor; scrollClass.lpszClassName=L"ChotkiScroll"; RegisterClassW(&scrollClass);
    RECT frame={0,0,px(1100),px(860)}; AdjustWindowRectExForDpi(&frame,WS_OVERLAPPEDWINDOW,FALSE,0,dpi);
    window=CreateWindowExW(0,cls.lpszClassName,automated ? L"Chotki — Review" : L"Chotki",WS_OVERLAPPEDWINDOW|WS_CLIPCHILDREN,CW_USEDEFAULT,CW_USEDEFAULT,frame.right-frame.left,frame.bottom-frame.top,NULL,NULL,cls.hInstance,NULL);
    if(!window) return 3;
    readerParking=CreateWindowExW(0,L"STATIC",L"",0,0,0,0,0,HWND_MESSAGE,NULL,cls.hInstance,NULL);
    currentParent=window; InterlockedExchangePointer(&postWindow,window);
    BOOL dark=TRUE; DwmSetWindowAttribute(window,20,&dark,sizeof(dark));
    callback(context,0,0); ShowWindow(window,automation ? SW_SHOWNOACTIVATE : startHidden ? SW_HIDE : SW_SHOW); UpdateWindow(window);
    if(!ch_tray_attach(window,automation)) {
        // A failed tray registration must never leave an inaccessible hidden app.
        ShowWindow(window,SW_SHOW);
        OutputDebugStringW(L"Chotki: tray icon registration failed; closing the window will quit.\n");
    }
    SetTimer(window,1,30000,NULL);
    ch_opening_start(window,automation || platformReview);
    if(automation==1) callback(context,-1,0);
    else if(automation==2) SetTimer(window,3,1000,NULL);
    MSG msg; int result;
    while((result=GetMessageW(&msg,NULL,0,0))>0) dispatchUI(&msg);
    for(int i=0;i<2;i++) if(pooledReaders[i] && IsWindow(pooledReaders[i])) {
        Visual *v=GetPropW(pooledReaders[i],L"ChotkiVisual");
        if(v) { while(v->links) { LinkRange *next=v->links->next; free(v->links); v->links=next; } while(v->ends) { ReadingRange *next=v->ends->next; free(v->ends); v->ends=next; } RemovePropW(pooledReaders[i],L"ChotkiVisual"); free(v); }
    }
    ch_opening_shutdown();
    if(reportWindow) {
        HWND child=GetDlgItem(reportWindow,7014); Visual *v=child ? GetPropW(child,L"ChotkiVisual") : NULL;
        if(v) { while(v->links) { LinkRange *next=v->links->next; free(v->links); v->links=next; } while(v->ends) { ReadingRange *next=v->ends->next; free(v->ends); v->ends=next; } RemovePropW(child,L"ChotkiVisual"); free(v); }
        DestroyWindow(reportWindow); reportWindow=NULL;
    }
    if(readerParking) DestroyWindow(readerParking); readerParking=NULL;
    DeleteObject(regular); DeleteObject(reading); DeleteObject(heading); DeleteObject(smallFont); DeleteObject(dateFont); DeleteObject(captionFont); DeleteObject(listFont); DeleteObject(ground); DeleteObject(panel);
    free(testFilePath); testFilePath=NULL;
    ch_notifications_close();
    ch_sound_close();
    if(instanceMutex) { CloseHandle(instanceMutex); instanceMutex=NULL; }
    OleUninitialize();
    return result<0 ? 4 : (int32_t)msg.wParam;
}

int32_t ch_first_visible_line(int32_t id) { return (int32_t)SendMessageW(findChild(id),EM_GETFIRSTVISIBLELINE,0,0); }

// Reader character positions use Rich Edit's UTF-16 indices and CR paragraph marks.
void ch_rich_style(int32_t id,int32_t start,int32_t length,int32_t flags,int32_t size,int32_t linkID) {
    HWND child=findChild(id); Visual *v=GetPropW(child,L"ChotkiVisual"); if(!v || v->kind!=19) return;
    CHARRANGE range={start,length<0 ? -1 : start+length}; SendMessageW(child,EM_EXSETSEL,0,(LPARAM)&range);
    CHARFORMAT2W format={0}; format.cbSize=sizeof(format);
    format.dwMask=CFM_FACE|CFM_SIZE|CFM_COLOR|CFM_BOLD|CFM_ITALIC|CFM_LINK|CFM_UNDERLINE;
    format.yHeight=size*15; // logical 96-DPI pixels converted to twips
    format.crTextColor=flags&128 ? foreground : flags&8 || (linkID>=0 && !(flags&128)) ? gold : flags&1024 ? violet : flags&4 ? muted : flags&512 ? parchmentDim : foreground;
    format.dwEffects=(flags&1 ? CFE_BOLD : 0)|(flags&2 ? CFE_ITALIC : 0);
    wcscpy_s(format.szFaceName,LF_FACESIZE,flags&256 ? L"Segoe UI Symbol" : flags&16 ? L"Segoe UI" : L"XCharter");
    SendMessageW(child,EM_SETCHARFORMAT,SCF_SELECTION,(LPARAM)&format);
    if(linkID>=0) {
        if(v->links && v->links->id==linkID && v->links->end==start && v->links->disclosure==(!!(flags&64))) v->links->end=start+length;
        else { LinkRange *link=calloc(1,sizeof(*link)); link->start=start; link->end=start+length; link->id=linkID; link->disclosure=!!(flags&64); link->next=v->links; v->links=link; }
    }
}
void ch_rich_finish(int32_t id) {
    HWND child=findChild(id); Visual *v=GetPropW(child,L"ChotkiVisual"); if(!v) return;
    v->suppressScroll++;
    CHARRANGE all={0,-1}; SendMessageW(child,EM_EXSETSEL,0,(LPARAM)&all);
    PARAFORMAT2 paragraph={0}; paragraph.cbSize=sizeof(paragraph); paragraph.dwMask=PFM_LINESPACING|PFM_SPACEAFTER|PFM_ALIGNMENT|PFM_TABSTOPS; paragraph.wAlignment=PFA_LEFT;
    paragraph.bLineSpacingRule=5; paragraph.dyLineSpacing=24; paragraph.dySpaceAfter=160;
    RECT area; GetClientRect(child,&area); paragraph.cTabCount=1; paragraph.rgxTabs[0]=MulDiv(max(px(120),area.right-px(30)),1440,dpi);
    SendMessageW(child,EM_SETPARAFORMAT,0,(LPARAM)&paragraph);
    paragraph.dwMask=PFM_SPACEAFTER; paragraph.dySpaceAfter=320;
    for(LinkRange *link=v->links;link;link=link->next) if(link->disclosure) {
        CHARRANGE heading={link->start,link->end};
        SendMessageW(child,EM_EXSETSEL,0,(LPARAM)&heading);
        SendMessageW(child,EM_SETPARAFORMAT,0,(LPARAM)&paragraph);
    }
    CHARRANGE top={0,0}; SendMessageW(child,EM_EXSETSEL,0,(LPARAM)&top);
    SendMessageW(child,EM_LINESCROLL,0,v->restoreLine-(int)SendMessageW(child,EM_GETFIRSTVISIBLELINE,0,0));
    v->suppressScroll--;
    RedrawWindow(GetParent(child),NULL,NULL,RDW_INVALIDATE|RDW_ERASE|RDW_ALLCHILDREN);
}
void ch_reader_dividers(int32_t id) {
    Visual *v=GetPropW(findChild(id),L"ChotkiVisual");
    if(v && v->kind==19) { v->flags|=32768; InvalidateRect(findChild(id),NULL,FALSE); }
}
void ch_rich_center(int32_t id) {
    HWND child=findChild(id); Visual *v=GetPropW(child,L"ChotkiVisual"); if(!v) return;
    int first=(int)SendMessageW(child,EM_GETFIRSTVISIBLELINE,0,0); CHARRANGE saved,all={0,-1};
    v->suppressScroll++; SendMessageW(child,EM_EXGETSEL,0,(LPARAM)&saved); SendMessageW(child,EM_EXSETSEL,0,(LPARAM)&all);
    PARAFORMAT paragraph={0}; paragraph.cbSize=sizeof(paragraph); paragraph.dwMask=PFM_ALIGNMENT; paragraph.wAlignment=PFA_CENTER;
    SendMessageW(child,EM_SETPARAFORMAT,0,(LPARAM)&paragraph); SendMessageW(child,EM_EXSETSEL,0,(LPARAM)&saved);
    SendMessageW(child,EM_LINESCROLL,0,first-(int)SendMessageW(child,EM_GETFIRSTVISIBLELINE,0,0)); v->suppressScroll--;
}
void ch_remove(int32_t id) {
    HWND child=findChild(id);
    if(child) { Visual *v=GetPropW(child,L"ChotkiVisual"); if(v && v->kind==19) parkReader(child); else { if(GetFocus()==child || IsChild(child,GetFocus())) SetFocus(GetParent(child)); DestroyWindow(child); } }
}
void ch_glossary_begin(int32_t x,int32_t y,int32_t width,int32_t height) {
    ch_glossary_close(); glossaryFocus=GetFocus();
    for(HWND child=GetWindow(window,GW_CHILD);child;child=GetWindow(child,GW_HWNDNEXT)) EnableWindow(child,FALSE);
    glossaryPanel=CreateWindowExW(WS_EX_CONTROLPARENT,L"ChotkiScroll",L"Glossary",WS_CHILD|WS_VISIBLE|WS_CLIPCHILDREN,px(x),px(y),px(width),px(height),window,(HMENU)6099,GetModuleHandleW(NULL),NULL);
    SetWindowPos(glossaryPanel,HWND_TOP,0,0,0,0,SWP_NOMOVE|SWP_NOSIZE|SWP_NOACTIVATE);
    currentParent=glossaryPanel;
}
void ch_glossary_close(void) {
    if(!glossaryPanel) return;
    if(IsChild(glossaryPanel,GetFocus())) SetFocus(window);
    parkReadersIn(glossaryPanel);
    DestroyWindow(glossaryPanel); glossaryPanel=NULL; currentParent=window;
    for(HWND child=GetWindow(window,GW_CHILD);child;child=GetWindow(child,GW_HWNDNEXT)) EnableWindow(child,TRUE);
    if(IsWindow(glossaryFocus)) SetFocus(glossaryFocus); glossaryFocus=NULL;
}
int32_t ch_open_url(const char *url) { wchar_t *value=wide(url); INT_PTR result=(INT_PTR)ShellExecuteW(window,L"open",value,NULL,NULL,SW_SHOWNORMAL); free(value); return result>32; }
int32_t ch_test_link(int32_t id,int32_t index) {
    if(!automation) return 0; HWND child=findChild(id); Visual *v=GetPropW(child,L"ChotkiVisual"); if(!v) return 0;
    LinkRange *found=NULL; LONG after=-1;
    for(int i=0;i<=index;i++) { found=NULL; for(LinkRange *link=v->links;link;link=link->next) if(link->start>after && (!found || link->start<found->start)) found=link; if(!found) return 0; after=found->start; }
    int originalLine=(int)SendMessageW(child,EM_GETFIRSTVISIBLELINE,0,0);
    ch_test_scroll_character(id,found->start,0);
    POINT point={0,0}; SendMessageW(child,EM_POSFROMCHAR,(WPARAM)&point,found->start);
    MSGFILTER event={0}; event.nmhdr.hwndFrom=child; event.nmhdr.idFrom=id; event.nmhdr.code=EN_MSGFILTER;
    event.msg=WM_LBUTTONUP; event.lParam=MAKELPARAM(point.x+1,point.y+2);
    SendMessageW(GetParent(child),WM_NOTIFY,id,(LPARAM)&event);
    ch_reader_scroll_line(id,originalLine); return 1;
}
int32_t ch_test_reader_painted(int32_t id) {
    if(!automation) return 0;
    HWND child=findChild(id); if(!child || !IsWindowVisible(child)) { printf("Visible reader check: id=%d missing=%d visible=%d\n",id,!child,child ? IsWindowVisible(child) : 0); return 0; }
    RedrawWindow(window,NULL,NULL,RDW_INVALIDATE|RDW_ERASE|RDW_ALLCHILDREN|RDW_UPDATENOW);
    RECT r; GetClientRect(child,&r); HDC dc=GetDC(child); int pixels=0;
    // Ignore the native scrollbar: its light track is not reader content.
    for(int y=0;y<r.bottom;y++) for(int x=0;x<r.right-px(24);x++) {
        COLORREF color=GetPixel(dc,x,y);
        if(color!=CLR_INVALID && GetRValue(color)>140 && GetGValue(color)>120) pixels++;
        if(pixels>50) { ReleaseDC(child,dc); return 1; }
    }
    RECT bounds; GetWindowRect(child,&bounds); POINT center={(bounds.left+bounds.right)/2,(bounds.top+bounds.bottom)/2};
    printf("Visible reader check: id=%d chars=%d client=%ldx%ld firstLine=%lld coveringControl=%d color=%lx\n",id,GetWindowTextLengthW(child),r.right,r.bottom,(long long)SendMessageW(child,EM_GETFIRSTVISIBLELINE,0,0),GetDlgCtrlID(WindowFromPoint(center)),(unsigned long)GetPixel(dc,5,5));
    ReleaseDC(child,dc); return 0;
}
int32_t ch_test_rich_flags(int32_t id,int32_t start) {
    if(!automation) return -1; HWND child=findChild(id); CHARRANGE old,one={start,start+1}; SendMessageW(child,EM_EXGETSEL,0,(LPARAM)&old); SendMessageW(child,EM_EXSETSEL,0,(LPARAM)&one);
    CHARFORMAT2W format={0}; format.cbSize=sizeof(format); SendMessageW(child,EM_GETCHARFORMAT,SCF_SELECTION,(LPARAM)&format); SendMessageW(child,EM_EXSETSEL,0,(LPARAM)&old);
    Visual *v=GetPropW(child,L"ChotkiVisual"); int linked=0;
    if(v) for(LinkRange *link=v->links;link;link=link->next) if(start>=link->start && start<link->end) { linked=1; break; }
    return (format.dwEffects&CFE_BOLD ? 1 : 0)|(format.dwEffects&CFE_ITALIC ? 2 : 0)|(linked ? 32 : 0)|(format.crTextColor==gold ? 64 : 0);
}

void ch_focus(int32_t id) { SetFocus(findChild(id)); }
void ch_glossary_resize(int32_t x,int32_t y,int32_t width,int32_t height) {
    if(!glossaryPanel) return;
    SetWindowPos(glossaryPanel,NULL,px(x),px(y),px(width),px(height),SWP_NOZORDER|SWP_NOACTIVATE);
    HWND search=GetDlgItem(glossaryPanel,6060),reader=GetDlgItem(glossaryPanel,6014);
    SetWindowPos(search,NULL,0,0,px(width-24),px(34),SWP_NOMOVE|SWP_NOZORDER|SWP_NOACTIVATE);
    SetWindowPos(reader,NULL,0,0,px(width-24),px(height-193),SWP_NOMOVE|SWP_NOZORDER|SWP_NOACTIVATE);
}
int32_t ch_test_link_key(int32_t id) {
    if(!automation) return 0; HWND child=findChild(id); Visual *v=GetPropW(child,L"ChotkiVisual"); if(!v || !v->links) return 0;
    LinkRange *first=v->links; for(LinkRange *link=v->links;link;link=link->next) if(link->start<first->start) first=link;
    CHARRANGE range={first->start,first->end}; SendMessageW(child,EM_EXSETSEL,0,(LPARAM)&range);
    SendMessageW(child,WM_KEYDOWN,VK_RETURN,0); return 1;
}

void ch_flush(void) { fflush(NULL); }

int32_t ch_test_reader_identity(int32_t id) { Visual *v=GetPropW(findChild(id),L"ChotkiVisual"); return automation && v ? v->serial : 0; }
