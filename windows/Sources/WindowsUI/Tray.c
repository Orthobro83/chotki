#define UNICODE
#define _UNICODE
#include "WindowsUI.h"
#include <windows.h>
#include <shellapi.h>
#include <math.h>
#include <string.h>
#include <stdlib.h>

#define TRAY_MESSAGE (WM_APP + 20)
static NOTIFYICONDATAW icon;
static UINT taskbarCreated;
static int attached, enabled = 1, automated;
static double circles[96], bars[48], foot[8];
static int circleCount, barCount;

// Geometry is supplied by ChotkiCore, shared with the macOS mark.
void ch_tray_geometry(const double *knots, int32_t count, const double *rects, int32_t rectangles, const double *polygon) {
    circleCount = count < 32 ? count : 32; barCount = rectangles < 12 ? rectangles : 12;
    memcpy(circles, knots, circleCount * 3 * sizeof(double));
    memcpy(bars, rects, barCount * 4 * sizeof(double)); memcpy(foot, polygon, sizeof(foot));
}
static HICON ropeIcon(void) {
    int size = GetSystemMetrics(SM_CXSMICON);
    BITMAPINFO info = {0}; info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    info.bmiHeader.biWidth = size; info.bmiHeader.biHeight = -size;
    info.bmiHeader.biPlanes = 1; info.bmiHeader.biBitCount = 32; info.bmiHeader.biCompression = BI_RGB;
    void *pixels; HDC dc = CreateCompatibleDC(NULL);
    HBITMAP color = CreateDIBSection(dc, &info, DIB_RGB_COLORS, &pixels, NULL, 0);
    if (!color) { DeleteDC(dc); return NULL; }
    memset(pixels, 0, size * size * 4);
    HGDIOBJ prior = SelectObject(dc, color), brush = SelectObject(dc, GetStockObject(WHITE_BRUSH)), pen = SelectObject(dc, GetStockObject(NULL_PEN));
    double scale = size - 2;
    for (int i=0; i<circleCount; i++) {
        double x=1+circles[i*3]*scale, y=1+circles[i*3+1]*scale, r=fmax(.65,circles[i*3+2]*scale);
        Ellipse(dc,(int)floor(x-r),(int)floor(y-r),(int)ceil(x+r),(int)ceil(y+r));
    }
    for (int i=0; i<barCount; i++) {
        double *b=bars+i*4;
        Rectangle(dc,(int)floor(1+b[0]*scale),(int)floor(1+b[1]*scale),(int)ceil(1+(b[0]+b[2])*scale),(int)ceil(1+(b[1]+b[3])*scale));
    }
    POINT polygon[4]; for(int i=0;i<4;i++) { polygon[i].x=(LONG)round(1+foot[i*2]*scale); polygon[i].y=(LONG)round(1+foot[i*2+1]*scale); }
    Polygon(dc,polygon,4); GdiFlush();
    // Explicit alpha: GDI shapes do not write alpha into a 32-bit DIB.
    unsigned char *p=pixels;
    for(int i=0;i<size*size;i++) if(p[i*4]) { p[i*4]=39; p[i*4+1]=162; p[i*4+2]=201; p[i*4+3]=255; }
    SelectObject(dc,pen); SelectObject(dc,brush); SelectObject(dc,prior); DeleteDC(dc);
    // Initialize the AND mask; CreateBitmap with NULL bits leaves it undefined.
    size_t maskBytes=((size+15)/16)*2*size;
    void *maskBits=calloc(maskBytes,1);
    HBITMAP mask=CreateBitmap(size,size,1,1,maskBits); free(maskBits);
    ICONINFO details={TRUE,0,0,mask,color}; HICON result=CreateIconIndirect(&details);
    DeleteObject(mask); DeleteObject(color); return result;
}
static int addIcon(void) {
    attached=Shell_NotifyIconW(NIM_ADD,&icon);
    if(attached) { icon.uVersion=NOTIFYICON_VERSION_4; Shell_NotifyIconW(NIM_SETVERSION,&icon); }
    return attached;
}
int ch_tray_attach(void *owner, int automation) {
    automated=automation; taskbarCreated=RegisterWindowMessageW(L"TaskbarCreated");
    memset(&icon,0,sizeof(icon)); icon.cbSize=sizeof(icon); icon.hWnd=owner; icon.uID=1;
    icon.uFlags=NIF_MESSAGE|NIF_ICON|NIF_TIP|NIF_SHOWTIP; icon.uCallbackMessage=TRAY_MESSAGE;
    icon.hIcon=ropeIcon(); wcscpy(icon.szTip,L"Chotki");
    return icon.hIcon && addIcon();
}
void ch_tray_detach(void) {
    if(attached) Shell_NotifyIconW(NIM_DELETE,&icon);
    attached=0; if(icon.hIcon) { DestroyIcon(icon.hIcon); icon.hIcon=NULL; }
}
void ch_tray_enabled(int32_t value) { enabled=value != 0; }
int32_t ch_tray_present(void) { return attached; }
extern void ch_opening_show_if_needed(void);
void ch_foreground(void) {
    ShowWindow(icon.hWnd, IsIconic(icon.hWnd) ? SW_RESTORE : SW_SHOW);
    SetForegroundWindow(icon.hWnd);
    ch_opening_show_if_needed();
}
static HMENU trayMenu(void) {
    HMENU menu=CreatePopupMenu();
    AppendMenuW(menu,MF_STRING,CH_TRAY_OPEN,L"Open Chotki");
    AppendMenuW(menu,MF_STRING,CH_TRAY_TOGGLE,enabled ? L"Silence notifications" : L"Enable notifications");
    AppendMenuW(menu,MF_STRING,CH_TRAY_SETTINGS,L"Settings");
    AppendMenuW(menu,MF_STRING,CH_TRAY_QUIT,L"Quit");
    return menu;
}
static void showMenu(POINT point) {
    HMENU menu=trayMenu(); SetForegroundWindow(icon.hWnd);
    UINT command=TrackPopupMenu(menu,TPM_RETURNCMD|TPM_RIGHTBUTTON,point.x,point.y,0,icon.hWnd,NULL);
    DestroyMenu(menu); PostMessageW(icon.hWnd,WM_NULL,0,0);
    if(command) ch_command(command);
    if(attached && command!=CH_TRAY_OPEN && command!=CH_TRAY_SETTINGS) Shell_NotifyIconW(NIM_SETFOCUS,&icon);
}
int ch_tray_message(UINT message, WPARAM wp, LPARAM lp) {
    if(taskbarCreated && message==taskbarCreated) { attached=0; if(!addIcon()) ch_foreground(); return 1; }
    if(message!=TRAY_MESSAGE) return 0;
    UINT event=LOWORD(lp);
    if(event==NIN_SELECT || event==NIN_KEYSELECT || event==WM_CONTEXTMENU) {
        POINT point={(short)LOWORD(wp),(short)HIWORD(wp)};
        if(point.x==-1 && point.y==-1) { NOTIFYICONIDENTIFIER id={sizeof(id),icon.hWnd,icon.uID,{0}}; RECT r; if(SUCCEEDED(Shell_NotifyIconGetRect(&id,&r))) { point.x=r.left; point.y=r.bottom; } else GetCursorPos(&point); }
        showMenu(point);
    }
    return 1;
}
// Review-only hooks inspect the real menu and dispatch its actual command IDs.
int32_t ch_test_tray(int32_t command) {
    if(!automated || !attached) return 0;
    HMENU menu=trayMenu(); wchar_t label[64];
    GetMenuStringW(menu,CH_TRAY_TOGGLE,label,64,MF_BYCOMMAND);
    int valid=GetMenuItemCount(menu)==4 && wcscmp(label,enabled ? L"Silence notifications" : L"Enable notifications")==0;
    for(int i=0;i<4;i++) valid=valid && GetMenuItemID(menu,i)==CH_TRAY_OPEN+i;
    DestroyMenu(menu);
    if(!valid) return 0;
    if(command==0) return 1;
    if(command<CH_TRAY_OPEN || command>CH_TRAY_QUIT) return 0;
    ch_command(command); ch_pump(); return 1;
}
int32_t ch_test_window(int32_t operation) {
    if(!automated) return -1;
    if(operation==1) SendMessageW(icon.hWnd,WM_CLOSE,0,0);
    if(operation==2) ShowWindow(icon.hWnd,SW_MINIMIZE);
    if(operation==3) { Shell_NotifyIconW(NIM_DELETE,&icon); SendMessageW(icon.hWnd,taskbarCreated,0,0); }
    return IsWindowVisible(icon.hWnd) && !IsIconic(icon.hWnd) && (operation!=0 || GetForegroundWindow()==icon.hWnd);
}
