# Test Files for Build 4

This directory contains sample files for manual testing of the file parsing functionality in Build 4.

## Files Included

### VTT Files (WebVTT subtitle format)

1. **simple-meeting.vtt**
   - Short 5-exchange meeting
   - 3 speakers: Sarah Chen, Mike Rodriguez, Alex Kim
   - ~30 seconds duration
   - Tests: Speaker extraction, timestamp parsing

2. **team-standup.vtt**
   - Daily standup meeting
   - 3 speakers: Jordan Taylor, Pat Wilson, Sam Lee
   - ~37 seconds duration
   - Tests: Multiple speakers, sequential dialogue

3. **client-call.vtt**
   - Client review call
   - 3 speakers: Account Manager, Client Stakeholder, Project Lead
   - ~44 seconds duration
   - Tests: Professional dialogue, proposal discussion

### Plain Text

4. **sample-transcript.txt**
   - Full meeting transcript with speaker names inline
   - Includes attendee list, dialogue, and action items
   - ~450 words
   - Tests: Plain text parsing, no timestamp handling

## How to Use

1. **Import into MeetingPrep**:
   - Create a new project
   - Click "Import" button
   - Select one or more test files
   - Verify parsing results

2. **Expected Results**:
   - **VTT files**: Should extract speakers and show in "Participants" section
   - **Text files**: Should display full content in "Summary" section
   - **Processing**: Instant (no delay in Build 4)
   - **Raw text**: Visible in summary detail panel

3. **Verification Checklist**:
   - [ ] File imports without error
   - [ ] Speakers extracted correctly (VTT only)
   - [ ] Full text appears in Summary section
   - [ ] No processing delay
   - [ ] Timestamps preserved in segments (internal)
   - [ ] Key points show file metadata

## Build 4 Scope

- ✅ VTT parsing with speaker detection
- ✅ SRT parsing (not included in test files, but supported)
- ✅ Plain text parsing
- ✅ PDF parsing (create your own PDF to test)
- ❌ PPTX/Keynote (deferred to Build 8)
- ❌ Audio transcription (deferred to Build 7)

## Creating Additional Test Files

### VTT Format Template:
```
WEBVTT

00:00:00.000 --> 00:00:05.000
<v Speaker Name>Dialogue here

00:00:05.000 --> 00:00:10.000
<v Another Speaker>More dialogue
```

### SRT Format Template:
```
1
00:00:00,000 --> 00:00:05,000
First subtitle line

2
00:00:05,000 --> 00:00:10,000
Second subtitle line
```

Save files with appropriate extensions (.vtt, .srt, .txt) and import to test.
