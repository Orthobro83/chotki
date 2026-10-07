#define NOMINMAX
#include <windows.h>
#include <gdiplus.h>
#include <memory>
#include <string>
#include <algorithm>
#include <cmath>
#include <vector>

extern "C" void ch_draw_art(void *context, const wchar_t *path, int x, int y, int width, int height, double fx, double fy, int stationary, double progress, int imageNumber) {
    if (!path || width<=0 || height<=0) return;
    static ULONG_PTR token = 0;
    if (!token) { Gdiplus::GdiplusStartupInput input; if (Gdiplus::GdiplusStartup(&token, &input, nullptr) != Gdiplus::Ok) return; }
    static std::wstring held;
    static std::unique_ptr<Gdiplus::Image> image;
    if (held != path) { held = path; image.reset(Gdiplus::Image::FromFile(path)); }
    if (!image || image->GetLastStatus() != Gdiplus::Ok) return;
    double iw = image->GetWidth(), ih = image->GetHeight();
    // Same cover + 8% overscan and approved subject crop as the Mac resting frame.
    double scale = std::max(width / iw, height / ih) * (stationary ? 1.0 : 1.08);
    double rw = iw * scale, rh = ih * scale;
    double ox = std::clamp(width * .5 - rw * fx, width - rw, 0.0);
    double oy = stationary ? 0 : std::clamp(height * .4 - rh * fy, height - rh, 0.0);
    if(!stationary) {
        auto nearby=[](double end,double lower,double travel,double sign) {
            double preferred=sign>0 ? -end : end-lower,opposite=sign>0 ? end-lower : -end;
            double direction=preferred>=std::min(travel,opposite) ? sign : -sign;
            return std::clamp(end+direction*travel,lower,0.0);
        };
        double sx=nearby(ox,width-rw,14,imageNumber%2==0 ? 1 : -1);
        double sy=nearby(oy,height-rh,18,imageNumber%3==0 ? 1 : -1);
        // Smoothly arrive at the approved crop, then hold without repainting.
        double eased=progress*progress*(3-2*progress);
        ox=sx+(ox-sx)*eased; oy=sy+(oy-sy)*eased;
    }
    Gdiplus::Graphics graphics(static_cast<HDC>(context));
    graphics.SetInterpolationMode(Gdiplus::InterpolationModeHighQualityBicubic);
    graphics.DrawImage(image.get(), Gdiplus::RectF(float(x + ox), float(y + oy), float(rw), float(rh)));
    Gdiplus::LinearGradientBrush shade(Gdiplus::Point(x,y), Gdiplus::Point(x,y + height),
                                     Gdiplus::Color(0,0,0,0), Gdiplus::Color(220,0,0,0));
    Gdiplus::Color stops[] = {Gdiplus::Color(0,0,0,0),Gdiplus::Color(0,0,0,0),Gdiplus::Color(217,0,0,0)};
    Gdiplus::REAL positions[] = {0.0f,0.2f,1.0f};
    shade.SetInterpolationColors(stops,positions,3);
    graphics.FillRectangle(&shade,x,y,width,height);
}

// Sample the same two restrained radial washes used by the macOS backdrop.
extern "C" void ch_draw_backdrop(void *context,int width,int height,int offsetX,int offsetY) {
    if(width<=0 || height<=0) return;
    constexpr int sw=240,sh=180;
    static int heldW=0,heldH=0;
    static std::vector<unsigned int> pixels(sw*sh);
    if(heldW!=width || heldH!=height) {
        heldW=width; heldH=height;
        for(int y=0;y<sh;y++) for(int x=0;x<sw;x++) {
            double gx=x*double(width)/(sw-1),gy=y*double(height)/(sh-1);
            double a=.14*std::max(0.0,1-std::hypot(gx,gy)/(width*.7));
            double b=.10*std::max(0.0,1-std::hypot(width-gx,height-gy)/(width*.6));
            int r=int((21*(1-a)+232*a)*(1-b)+201*b);
            int g=int((22*(1-a)+223*a)*(1-b)+162*b);
            int blue=int((28*(1-a)+205*a)*(1-b)+39*b);
            pixels[y*sw+x]=(r<<16)|(g<<8)|blue;
        }
    }
    BITMAPINFO info={}; info.bmiHeader.biSize=sizeof(BITMAPINFOHEADER); info.bmiHeader.biWidth=sw;
    info.bmiHeader.biHeight=-sh; info.bmiHeader.biPlanes=1; info.bmiHeader.biBitCount=32;
    StretchDIBits(static_cast<HDC>(context),-offsetX,-offsetY,width,height,0,0,sw,sh,pixels.data(),&info,DIB_RGB_COLORS,SRCCOPY);
}

// Smooth circles retain the Mac rope's shape even at a five-pixel compact size.
extern "C" void ch_draw_knots(void *context,int x,int y,int width,int count,int target,int diameter,int step) {
    if(target<=0 || width<=0) return;
    static ULONG_PTR token=0;
    if(!token) { Gdiplus::GdiplusStartupInput input; if(Gdiplus::GdiplusStartup(&token,&input,nullptr)!=Gdiplus::Ok) return; }
    Gdiplus::Graphics graphics(static_cast<HDC>(context));
    graphics.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
    Gdiplus::SolidBrush filled(Gdiplus::Color(255,201,162,39)),empty(Gdiplus::Color(255,28,30,38));
    int columns=std::min(10,target);
    for(int i=0;i<target;i++) {
        float left=float(x)+(float(i%columns)+.5f)*float(width)/float(columns)-float(diameter)/2;
        graphics.FillEllipse(i<count ? &filled : &empty,left,float(y+(i/columns)*step),float(diameter),float(diameter));
    }
}

// The rope as a ring: counted knots filled, the next one ringed in gold, the rest outlined, and a
// larger red bead after every tenth knot. Geometry is core's (RopeCircleLayout), in 96-dpi units;
// only the scale is applied here. `centres` holds the knots, then the beads.
extern "C" void ch_draw_ring(void *context,int x,int y,int count,int target,const double *centres,int knots,int beads,double dot,double bead,double side,int dpi) {
    (void)side;
    if(target<=0 || knots!=target || !centres) return;
    static ULONG_PTR token=0;
    if(!token) { Gdiplus::GdiplusStartupInput input; if(Gdiplus::GdiplusStartup(&token,&input,nullptr)!=Gdiplus::Ok) return; }
    Gdiplus::Graphics graphics(static_cast<HDC>(context));
    graphics.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
    float scale=float(dpi)/96, d=float(dot)*scale;
    Gdiplus::SolidBrush filled(Gdiplus::Color(255,201,162,39)),empty(Gdiplus::Color(255,28,30,38));
    for(int i=0;i<target;i++) {
        float left=float(x)+float(centres[2*i])*scale-d/2, top=float(y)+float(centres[2*i+1])*scale-d/2;
        if(i<count) { graphics.FillEllipse(&filled,left,top,d,d); continue; }
        graphics.FillEllipse(&empty,left,top,d,d);
        bool next=i==count;
        float width=next ? std::max(1.2f,float(dot)*.28f)*scale : std::max(0.7f,float(dot)*.14f)*scale;
        Gdiplus::Pen pen(next ? Gdiplus::Color(255,201,162,39) : Gdiplus::Color(140,110,106,98),width);
        graphics.DrawEllipse(&pen,left+width/2,top+width/2,d-width,d-width);
    }
    // Beads: the liturgy-day red (A63A38), dimmer until the tenth knot before them is counted.
    float b=float(bead)*scale;
    for(int j=0;j<beads;j++) {
        const double *c=centres+2*(knots+j);
        bool passed=j==0 || count>=j*10;
        Gdiplus::SolidBrush red(Gdiplus::Color(passed ? 255 : 140,166,58,56));
        graphics.FillEllipse(&red,float(x)+float(c[0])*scale-b/2,float(y)+float(c[1])*scale-b/2,b,b);
    }
}

// macOS VenerationBorder: four open corners, hairlines, arrow/diamond tiles
// and the outlined knot, in parchment at eleven percent opacity.
extern "C" void ch_draw_border(void *context,int x,int y,int width,int height,int dpi) {
    static ULONG_PTR token=0;
    if(!token) { Gdiplus::GdiplusStartupInput input; if(Gdiplus::GdiplusStartup(&token,&input,nullptr)!=Gdiplus::Ok) return; }
    Gdiplus::Graphics g(static_cast<HDC>(context)); g.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
    float scale=float(dpi)/96, w=width/scale,h=height/scale;
    float ax=std::min(74.0f,(w-28)/2-8),ay=std::min(74.0f,(h-28)/2-8);
    if(ax<=0 || ay<=0) return;
    g.TranslateTransform(float(x),float(y)); g.ScaleTransform(scale,scale);
    Gdiplus::Color ink(28,232,223,205); Gdiplus::SolidBrush brush(ink);
    auto polygon=[&](const std::vector<Gdiplus::PointF>& points) { g.FillPolygon(&brush,points.data(),(INT)points.size()); };
    for(int corner=0;corner<4;corner++) {
        auto state=g.Save(); g.TranslateTransform(corner%2 ? w-14 : 14,corner/2 ? h-14 : 14); g.ScaleTransform(corner%2 ? -1.0f : 1.0f,corner/2 ? -1.0f : 1.0f);
        for(int vertical=0;vertical<2;vertical++) {
            auto armState=g.Save(); if(vertical) { Gdiplus::Matrix swap(0,1,1,0,0,0); g.MultiplyTransform(&swap); }
            float length=vertical ? ay : ax;
            if(length>22) {
                g.FillRectangle(&brush,22.0f,0.0f,length-22,0.9f); g.FillRectangle(&brush,22.0f,10.1f,length-22,0.9f);
                for(float t=22;t+16<=length;t+=16) {
                    polygon({{t+8,1.82f},{t+11.52f,5.5f},{t+8,9.18f},{t+4.48f,5.5f}});
                    polygon({{t,5.5f},{t+2.72f,3.82f},{t+2.72f,7.18f}});
                    polygon({{t+16,5.5f},{t+13.28f,3.82f},{t+13.28f,7.18f}});
                }
            }
            g.Restore(armState);
        }
        for(int ring=0;ring<2;ring++) {
            float radius=ring ? 6.38f : 10.4f; Gdiplus::Pen pen(ink,ring ? 1.6f : 1.0f);
            Gdiplus::PointF points[]={{11,11-radius},{11+radius,11},{11,11+radius},{11-radius,11}};
            g.DrawPolygon(&pen,points,4);
        }
        g.Restore(state);
    }
    auto edge=[&](Gdiplus::PointF from,Gdiplus::PointF to) {
        if(from.X==to.X && from.Y==to.Y) return;
        Gdiplus::LinearGradientBrush fade(from,to,Gdiplus::Color(0,232,223,205),ink);
        Gdiplus::Color colors[]={Gdiplus::Color(0,232,223,205),ink,ink,Gdiplus::Color(0,232,223,205)};
        Gdiplus::REAL positions[]={0,.22f,.78f,1}; fade.SetInterpolationColors(colors,positions,4);
        Gdiplus::Pen pen(&fade,.9f); g.DrawLine(&pen,from,to);
    };
    edge({14+ax,14},{w-14-ax,14}); edge({14+ax,h-14},{w-14-ax,h-14});
    edge({14,14+ay},{14,h-14-ay}); edge({w-14,14+ay},{w-14,h-14-ay});
}
