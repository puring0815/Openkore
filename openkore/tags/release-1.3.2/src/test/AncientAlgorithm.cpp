// This is Tools.cpp from OpenKore 1.2, without the wall avoiding features
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#define SOLUTION_MAX 5000
#define FULL_LIST_MAX 480000
#define OPEN_LIST_MAX 160000
#define LOOKUPS_MAX 200000
#define SESSION_MAX 10

#define G_NORMAL 1
#ifndef WIN32

#include <sys/time.h>
#define WINAPI
#define DLLEXPORT

typedef unsigned long int DWORD;
typedef bool BOOL;

DWORD GetTickCount ()
{
	struct timeval tv;
	gettimeofday(&tv, NULL);
	return (tv.tv_sec*1000) + (tv.tv_usec/1000);
}

#else

#include <windows.h>
#include <Tlhelp32.h>
#define DLLEXPORT __declspec(dllexport)

static int isNT = 0;

#endif /* WIN32 */

struct pos {
	unsigned short x;
	unsigned short y;
};

struct pos_ai {
	pos p;
	float g;
	float f;
	int parent;
};

struct pos_list {
	unsigned int size;
	pos array[];
};

struct lookups_list {
	unsigned int size;
	float *array;
};

typedef struct QuicksortFloat {
	float val;
	int index;
} QuicksortFloat;

struct index_list {
	unsigned int size;
	QuicksortFloat *array;
};

struct pos_ai_list {
	unsigned int size;
	pos_ai *array;
};

struct CalcPath_session {
	pos_list *solution;
	pos_ai_list fullList;
	index_list openList;
	lookups_list lookup;
	char* map;
	unsigned long width;
	unsigned long height;
	pos * start;
	pos * dest;
	DWORD time_max;
	BOOL active;
};

CalcPath_session g_sessions[SESSION_MAX];

#ifdef __cplusplus
#define CEXTERN extern "C"
extern "C" {
#else
#define CEXTERN
#endif

extern DLLEXPORT DWORD WINAPI CalcPath_init(pos_list *solution, char* map, unsigned long width,unsigned long height,
			pos * start, pos * dest, DWORD time_max); 
extern DLLEXPORT DWORD WINAPI CalcPath_pathStep(DWORD session);
extern DLLEXPORT void WINAPI CalcPath_destroy(DWORD session);

#ifdef WIN32
extern DLLEXPORT int WINAPI InjectDLL(DWORD ProcID, LPCTSTR dll);
extern DLLEXPORT DWORD WINAPI GetProcByName (char * name);
#endif /* WIN32 */

#ifdef __cplusplus
}
#endif


int QuickfindFloatMax(QuicksortFloat* a, float val, int lo, int hi)
{
	int x = (lo+hi)>>1;
	if (val == a[x].val)
		return x;
	if (x != hi - 1 && val < a[x].val)
		return QuickfindFloatMax(a, val, x, hi);
	if (x != lo && val > a[x].val)
		return QuickfindFloatMax(a, val, lo, x);
	if (val < a[x].val)
		return x+1;
	else
		return x;
}

inline char CalcPath_getMap(char *map, unsigned long width, unsigned long height, pos *p) {
	if (p->x >= width || p->y >= height) {
		return 1;
	} else {
		return map[(p->y*width)+p->x];
	}
}

DLLEXPORT DWORD WINAPI CalcPath_init (pos_list *solution, char* map, unsigned long width, unsigned long height,
							pos * start, pos * dest, DWORD time_max) {
	DWORD i;
	int session = -1;
	int index;
	for (i=0;i<SESSION_MAX;i++) {
		if (!g_sessions[i].active) {
			session = i;
			break;
		}
	}
	if (session < 0) {
		return session;
	}
	g_sessions[session].active = 1;
	g_sessions[session].solution = solution;
	g_sessions[session].map = map;
	g_sessions[session].width = width;
	g_sessions[session].height = height;
	g_sessions[session].start = start;
	g_sessions[session].dest = dest;
	g_sessions[session].time_max = time_max;

	g_sessions[session].fullList.array = (pos_ai*)malloc(FULL_LIST_MAX*sizeof(pos_ai));
	g_sessions[session].openList.array = (QuicksortFloat*)malloc(OPEN_LIST_MAX*sizeof(QuicksortFloat));
	g_sessions[session].lookup.array = (float*)malloc(LOOKUPS_MAX*sizeof(float));

	pos_ai_list *fullList = &g_sessions[session].fullList;
	index_list *openList = &g_sessions[session].openList;
	lookups_list *lookup = &g_sessions[session].lookup;

	solution->size = 0;
	openList->size = 0;
	fullList->size = 0;
	fullList->array[0].p = *start;
	fullList->array[0].g = 0;
	fullList->array[0].f = (float)abs(start->x - dest->x) + abs(start->y - dest->y);
	fullList->array[0].parent = -1;
	fullList->size++;
	openList->array[0].val = fullList->array[0].f;
	openList->array[0].index = 0;
	openList->size++;
	for (i = 0; i < width*height;i++) {
		lookup->array[i] = 999999;
	}
	index = fullList->array[0].p.y*width + fullList->array[0].p.x;
	lookup->array[index] = fullList->array[0].g;
	lookup->size = width*height;
	return session;
}

DLLEXPORT DWORD WINAPI CalcPath_pathStep(DWORD session) {
	char type = 0;
	pos mappos;
	float newg;
	unsigned char successors_size;
	int j, cur, successors_start,suc, found,index;
	BOOL done = 1;
	DWORD timeout = GetTickCount();

	pos_list *solution = g_sessions[session].solution;
	pos_ai_list *fullList = &g_sessions[session].fullList;
	index_list *openList = &g_sessions[session].openList;
	lookups_list *lookup = &g_sessions[session].lookup;
	char* map = g_sessions[session].map;
	unsigned long width = g_sessions[session].width;
	unsigned long height = g_sessions[session].height;
	pos * start = g_sessions[session].start;
	pos * dest = g_sessions[session].dest;
	DWORD time_max = g_sessions[session].time_max;

	if (start == NULL && dest == NULL)
		return 0;
	if (CalcPath_getMap(map, width, height, start) || CalcPath_getMap(map, width, height, dest)) {
		return 0;
	}
	while (1) {
		if (GetTickCount() - timeout > time_max) {
			break;
		}
		//get next from the list
		if (openList->size == 0) {
			//failed!
			done = 0;
			break;
		}
		openList->size--;
		cur = openList->array[openList->size].index;

		//has higher g value than another with same state?
		index = fullList->array[cur].p.y*width + fullList->array[cur].p.x;
		if (fullList->array[cur].g > lookup->array[index])
			continue;

		//check if finished
		if (dest->x == fullList->array[cur].p.x && dest->y == fullList->array[cur].p.y) {
			do {
				solution->array[solution->size] = fullList->array[cur].p;
				cur = fullList->array[cur].parent;
				solution->size++;
			} while (cur != -1);
			done = 0;
			break;
		}

		//Get successors
		successors_start = fullList->size;
		successors_size = 0;
		mappos.x = fullList->array[cur].p.x-1;
		mappos.y = fullList->array[cur].p.y;
		if (CalcPath_getMap(map, width, height, &mappos) == type
			&& !(fullList->array[cur].parent >= 0 && fullList->array[fullList->array[cur].parent].p.x == mappos.x
			&& fullList->array[fullList->array[cur].parent].p.y == mappos.y)) {
			fullList->array[fullList->size].p = mappos;
			fullList->size++;
			successors_size++;
		}

		mappos.x = fullList->array[cur].p.x;
		mappos.y = fullList->array[cur].p.y-1;
		if (CalcPath_getMap(map, width, height, &mappos) == type
			&& !(fullList->array[cur].parent >= 0 && fullList->array[fullList->array[cur].parent].p.x == mappos.x
			&& fullList->array[fullList->array[cur].parent].p.y == mappos.y)) {
			fullList->array[fullList->size].p = mappos;
			fullList->size++;
			successors_size++;
		}

		mappos.x = fullList->array[cur].p.x+1;
		mappos.y = fullList->array[cur].p.y;
		if (CalcPath_getMap(map, width, height, &mappos) == type
			&& !(fullList->array[cur].parent >= 0 && fullList->array[fullList->array[cur].parent].p.x == mappos.x
			&& fullList->array[fullList->array[cur].parent].p.y == mappos.y)) {
			fullList->array[fullList->size].p = mappos;
			fullList->size++;
			successors_size++;
		}

		mappos.x = fullList->array[cur].p.x;
		mappos.y = fullList->array[cur].p.y+1;
		if (CalcPath_getMap(map, width, height, &mappos) == type
			&& !(fullList->array[cur].parent >= 0 && fullList->array[fullList->array[cur].parent].p.x == mappos.x
			&& fullList->array[fullList->array[cur].parent].p.y == mappos.y)) {
			fullList->array[fullList->size].p = mappos;
			fullList->size++;
			successors_size++;
		}

		//do the step
		newg = fullList->array[cur].g + G_NORMAL;
		for (j=0;j < successors_size;j++) {
			suc = successors_start+j;
			index = fullList->array[suc].p.y*width + fullList->array[suc].p.x;
			if (newg >= lookup->array[index])
				continue;

			fullList->array[suc].g = newg;
			fullList->array[suc].f = newg + abs(fullList->array[suc].p.x - dest->x) + abs(fullList->array[suc].p.y - dest->y);
			fullList->array[suc].parent = cur;

			lookup->array[index] = fullList->array[suc].g;

			if (openList->size > 0)
				found = QuickfindFloatMax(openList->array, fullList->array[suc].f, 0, openList->size);
			else
				found = 0;

			if (openList->size - found > 0) {
				memmove(openList->array+found+1,openList->array+found, sizeof(QuicksortFloat)*(openList->size - found));
			}

			openList->array[found].index = suc;
			openList->array[found].val = fullList->array[suc].f;
			openList->size++;
		}

	}
	return (DWORD)done;
}

DLLEXPORT void WINAPI CalcPath_destroy(DWORD session) {
	g_sessions[session].active = 0;
	free(g_sessions[session].fullList.array);
	free(g_sessions[session].openList.array);
	free(g_sessions[session].lookup.array);
}


#ifdef WIN32

typedef struct {
	DWORD hProcess;
	DWORD hThread;
} GetProcInfo;

static BOOL WINAPI GetProcessThread_Enum(HWND hwnd, LPARAM linfo)
{
	GetProcInfo *info = (GetProcInfo *) linfo;
	DWORD hProcess, hThread;

	hThread = GetWindowThreadProcessId(hwnd, &hProcess);
	if (!hProcess)
		return TRUE;

	if (info->hProcess != hProcess)
		return TRUE;
	else {
		info->hThread = hThread;
		return FALSE;
	}
}

static DWORD WINAPI GetProcessThread(DWORD hProcess)
{
	GetProcInfo info;

	ZeroMemory(&info, sizeof(GetProcInfo));
	info.hProcess = hProcess;
	EnumWindows((WNDENUMPROC) GetProcessThread_Enum, (LPARAM) &info);
	return info.hThread;
}


DLLEXPORT int WINAPI InjectDLL(DWORD ProcID, LPCTSTR dll)
{
	if (!isNT) {
		DWORD hThread = GetProcessThread(ProcID);
		if (!hThread)
			return 0;

		HMODULE lib = LoadLibrary(dll);
		if (!lib)
			return 0;

		LRESULT CALLBACK (*HookInject)(HWND hWnd, DWORD hThread);
		HookInject = (LRESULT CALLBACK (*)(HWND, DWORD)) GetProcAddress(lib, "HookInject");
		if (!HookInject) {
			MessageBox(0, "function HookInject not found", "", 0);
			FreeLibrary(lib);
			return 0;
		}

		LRESULT result = (*HookInject)((HWND) ProcID, hThread);
		FreeLibrary(lib);

		return (int) result;
	}


	/* Attach to ragexe */
	HANDLE hProcessToAttach = OpenProcess(PROCESS_ALL_ACCESS, FALSE, ProcID);
	if (!hProcessToAttach)
		return 0;

	LPVOID pAttachProcessMemory = NULL;
	DWORD dwBytesWritten = 0;
	char * dllRemove;

	/* Allocate a piece of memory in ragexe. */
	dllRemove = (char*)calloc(strlen(dll) + 1, 1);
	pAttachProcessMemory = VirtualAllocEx( 
		hProcessToAttach,
		NULL, 
		strlen(dll) + 1, 
		MEM_COMMIT,
		PAGE_EXECUTE_READWRITE );
	if (!pAttachProcessMemory) {
		CloseHandle(hProcessToAttach);
		return 0;
	}

	/* Write our DLL filename to that allocated piece of memory. */
	WriteProcessMemory( 
		hProcessToAttach, 
		pAttachProcessMemory, 
		(LPVOID)dll, strlen(dll) + 1,
		&dwBytesWritten );

	if (!dwBytesWritten)
		return 0;


	/* Create a remote thread in the ragexe.exe process, which
	   calls LoadLibraryA(our DLL filename) */
	HMODULE kDLL = GetModuleHandle("Kernel32");
	HANDLE hThread = CreateRemoteThread( hProcessToAttach, NULL, 0, 
		(LPTHREAD_START_ROUTINE)GetProcAddress(kDLL, "LoadLibraryA"),
		(LPVOID)pAttachProcessMemory, 0,   
		NULL);
	if (!hThread)
		return 0;

	WaitForSingleObject(hThread, INFINITE);

	/* Free the string we created */
	WriteProcessMemory( 
		hProcessToAttach, 
		pAttachProcessMemory, 
		(LPVOID)dllRemove, strlen(dll) + 1, 
		&dwBytesWritten );

	if (!dwBytesWritten)
		return 0;
	VirtualFreeEx( 
		hProcessToAttach,      
		pAttachProcessMemory, 
		strlen(dll) + 1, 
		MEM_RELEASE);

	if(hThread) CloseHandle(hThread);
	return 1;
}


DLLEXPORT DWORD WINAPI GetProcByName (char * name)
{
	if (isNT) {
		HANDLE toolhelp;
		PROCESSENTRY32 pe;
		pe.dwSize = sizeof(PROCESSENTRY32);
		toolhelp = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
		if (Process32First(toolhelp,&pe)) {
			do {
				if (!stricmp(name, pe.szExeFile)) {
					CloseHandle(toolhelp);
					return pe.th32ProcessID;
				}
			} while (Process32Next(toolhelp,&pe));
		}
		CloseHandle(toolhelp);
		return 0;
	} else {
		HWND hwnd = FindWindow(NULL, "Ragnarok");
		if (!hwnd)
			return 0;

		DWORD hProcess;
		GetWindowThreadProcessId(hwnd, &hProcess);
		return hProcess;
	}
}


CEXTERN BOOL WINAPI DllMain(HINSTANCE hInstance, DWORD dwReason, LPVOID _Reserved)
{
	switch(dwReason)
	{
	case DLL_PROCESS_ATTACH:
		int i;
		for (i=0;i<SESSION_MAX;i++) {
			g_sessions[i].active = 0;
		}

		OSVERSIONINFO version;
		version.dwOSVersionInfoSize = sizeof(OSVERSIONINFO);
		GetVersionEx(&version);
		isNT = version.dwPlatformId == VER_PLATFORM_WIN32_NT;
		break;

	case DLL_THREAD_ATTACH:
		break;

	case DLL_THREAD_DETACH:
		break;

	case DLL_PROCESS_DETACH:
		break;
	}
	return true;
}

#else

void _init() {
        int i;
        for (i=0;i<SESSION_MAX;i++) {
                g_sessions[i].active = 0;
        }
}

void _fini()
{
}

#endif /* WIN32 */
