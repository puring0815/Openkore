/*
 *  OpenKore Packet Length Extractor
 *  Copyright (C) 2006 - written by VCL
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#ifndef _VIEW_H_
#define _VIEW_H_

#include "mainframe.h"
#include "worker-thread.h"

class View: public MainFrame {
public:
	View();
	~View();
protected:
	void onBrowseClick(wxCommandEvent &event);
	void onExtractClick(wxCommandEvent &event);
	void onCancelClick(wxCommandEvent &event);
	void onAboutClick(wxCommandEvent &event);
	void onTimer(wxTimerEvent &event);
private:
	WorkerThread *thread;
	wxTimer timer;

	void saveRecvpackets(PacketLengthAnalyzer &analyzer);

	DECLARE_EVENT_TABLE();
};

#endif /* _VIEW_H_ */
