# ShowSCutilRecords
List SCutil records as a big human readable list

## Description:

ShowSCutilRecords provides two main functions that allow you to read and parse the SCutil values.

	SF_SCUTILSHOWALLRECORDSFLAT - This function will shows every record of every SubKey, flattened to be more easily accessible
	SF_SCUTILSHOWALLSUBRECORDSFORRECORDFLAT - Given an existing record, this function will show all associated subrecords

You should note that at first boot, the SCutil vars take some time to fully populate.


## How to use:

In a shell, Type:
	
	ShowSCutilRecords.sh

If you call the script unmodified, it will list all SCutil values.

Personally, I use diff on the results of this output to see what changes when you connect and disconnect to different networks.


## History:

1.0.1 - 17 Mar 2019

* First public release.
