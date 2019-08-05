# optimize-media
Bash Scripts related to optimizing/compressing media files


## Script: optimize-videos.sh
### Status: INCOMPLETE

### Testing

* need to double check ffmpeg for certain filesize videos


### Pending

* set tar command for compress and delete - (High)
* write function to display list of altered files - (Low)
* write function to track and calculate altered filesizes and total how much storage was saved. - (Low)

### Completed

* configured ffmpeg settings for avi,mov,mpeg,mkv,mp4
* set filesize criteria
* break apart filename
* wire up source and destination parameters - (High)
* created dogearfiles that are txt files with data about the batch session so that the script doesn't rerun that file again.
