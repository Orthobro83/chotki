#define UNICODE
#define _UNICODE
#include "WindowsUI.h"
#include <windows.h>
#include <mmsystem.h>
#include <stdlib.h>
#include <string.h>

// Independent output voices let a tick finish while the completion bell rings.
// Headers and samples live until waveOut has released them, never on Swift's stack.
typedef struct { HWAVEOUT output; WAVEHDR header; int prepared; } Voice;
// Voices 0-3 take ticks in rotation, 4 the bell, 5 the bead's tock.
static Voice voices[6];
static int nextTick, quietReview, playedTick, playedBell, playedTock;
static MMRESULT audioStatus;

void ch_sound_close(void) {
    for(int i=0;i<6;i++) {
        Voice *voice=&voices[i];
        if(voice->output) {
            waveOutReset(voice->output);
            if(voice->prepared) waveOutUnprepareHeader(voice->output,&voice->header,sizeof(voice->header));
            waveOutClose(voice->output);
        }
        free(voice->header.lpData); memset(voice,0,sizeof(*voice));
    }
}
static MMRESULT prepareVoice(Voice *voice,const unsigned char *wav,int32_t length) {
    if(length<44 || memcmp(wav,"RIFF",4) || memcmp(wav+8,"WAVEfmt ",8) || memcmp(wav+36,"data",4)) return MMSYSERR_INVALPARAM;
    WAVEFORMATEX format={0}; memcpy(&format,wav+20,16);
    DWORD bytes; memcpy(&bytes,wav+40,4);
    if(format.wFormatTag!=WAVE_FORMAT_PCM || format.nChannels!=1 || format.wBitsPerSample!=16 || bytes!=(DWORD)(length-44)) return MMSYSERR_INVALPARAM;
    MMRESULT result=waveOutOpen(&voice->output,WAVE_MAPPER,&format,0,0,CALLBACK_NULL);
    if(result!=MMSYSERR_NOERROR) return result;
    voice->header.lpData=malloc(bytes); if(!voice->header.lpData) return MMSYSERR_NOMEM;
    memcpy(voice->header.lpData,wav+44,bytes); voice->header.dwBufferLength=bytes;
    result=waveOutPrepareHeader(voice->output,&voice->header,sizeof(voice->header));
    voice->prepared=result==MMSYSERR_NOERROR; return result;
}
int32_t ch_sound_prepare(const unsigned char *tick,int32_t tickLength,const unsigned char *bell,int32_t bellLength,const unsigned char *tock,int32_t tockLength,int32_t review) {
    ch_sound_close(); quietReview=review!=0; nextTick=playedTick=playedBell=playedTock=0;
    audioStatus=0;
    for(int i=0;i<6;i++) {
        MMRESULT result=prepareVoice(&voices[i],i==5 ? tock : i==4 ? bell : tick,i==5 ? tockLength : i==4 ? bellLength : tickLength);
        if(result!=MMSYSERR_NOERROR) { audioStatus=result; ch_sound_close(); break; }
    }
    return audioStatus;
}
// kind: 0 tick, 1 bell, 2 tock.
int32_t ch_sound_play(int32_t kind) {
    if(audioStatus!=MMSYSERR_NOERROR || !voices[0].prepared) return audioStatus ? audioStatus : MMSYSERR_INVALHANDLE;
    if(kind==1) playedBell++; else if(kind==2) playedTock++; else playedTick++;
    if(quietReview) return 0;
    Voice *voice=&voices[kind==1 ? 4 : kind==2 ? 5 : (nextTick++%4)];
    if(voice->header.dwFlags&WHDR_INQUEUE) waveOutReset(voice->output);
    return waveOutWrite(voice->output,&voice->header,sizeof(voice->header));
}
int32_t ch_test_sound(int32_t kind) { return quietReview ? (kind==1 ? playedBell : kind==2 ? playedTock : playedTick) : -1; }
