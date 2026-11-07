OxWalk Annotated Step Count Dataset
9 December 2022

Scott Small(1,2), Lennart von Fritsch(1), Aiden Doherty(2), Sara Khalid(1), Andrew Price(1)

(1) University of Oxford, Nuffield Department of Orthopaedics, Rhemuatology, and Musculoskeletal Sciences
(2) University of Oxford, Nuffield Department of Population Health

DATA DESCRIPTION:
Annotated step data during unscripted, free living in 39 healthy adult volunteers (aged 18 and above) with no lower limb injury within the previous 6 months and who were able to walk without an assistive device. 
Participants wore four triaxial accelerometers concurrently (AX3, Axivity, Newcastle, UK), two placed side-by-side on the dominant wrist and two clipped to the dominant-side hip at the midsagittal plane. Accelerometers were synchronised using the Open Movement GUI software (v.1.0.0.42), with one recording at 100 Hz and the other at 25 Hz at each body location. Foot-facing video was captured using an action camera (Action Camera CT9500, Crosstour, Shenzhen, China) mounted at the participant’s beltline. 

DATA ANNOTATION:
Foot-facing video was captured for up to one hour using an action camera (Action Camera CT9500, Crosstour, Shenzhen, China) mounted at the participant’s beltline. Annotation of steps was conducted within video annotation software (Elan 6.0, The Language Archive, Nijmegen, Netherlands), where a step was defined as the act of purposeful lifting a foot and placing it in a new location. Steps were not required to be part of a repeating pattern and did not include foot shuffling, changing of foot alignment via pivoting, or shifting of weight from one foot to the other. 

DATASETS:
The accelerometer data in each file has been resampled and calibrated using the Open Movement GUI software package. Within each CSV file, a step is annotated by a single "1" at the approximate time of heel strike. 

Datasets are as follows:
1) "Wrist_100Hz": One Axivity AX3 accelerometer, recording at 100 Hz and +/- 8g on the dominant wrist within a silicone wristband, with axes aligned as prescribed by the manufacturer. <https://axivity.com/userguides/ax3/technical/#axis-alignment>
2) "Wrist_25Hz": One Axivity AX3 accelerometer, recording at 25 Hz and +/- 8g on the dominant wrist within a silicone wristband, with axes aligned as prescribed by the manufacturer. <https://axivity.com/userguides/ax3/technical/#axis-alignment>
1) "Hip_100Hz": One Axivity AX3 accelerometer, recording at 100 Hz and +/- 8g cliped at the beltline, laterally above the dominant leg, with the +X axis approximately aligned in the superior direction, and the positive Y axis aligned to face anteriorly.
2) "Hip_25Hz": One Axivity AX3 accelerometer, recording at 100 Hz and +/- 8g cliped at the beltline, laterally above the dominant leg, with the +X axis approximately aligned in the superior direction, and the positive Y axis aligned to face anteriorly.

METADATA:
Participant sex and age range are provided in metadata.csv

FUNDING:
This work was funded by the University of Oxford Clarendon Fund, the Wellcome Trust, and HDR UK

CITING THE DATASET IN YOUR WORK:
When using this data, please cite the DOI for this archive, in addition to the associated development manuscript as listed in the description on the Oxford Research Archive page for this dataset.

CONTACT:
If you have questions please contact aiden.doherty@ndph.ox.ac.uk, or visit our website: https://www.bdi.ox.ac.uk/research/wearables-group
