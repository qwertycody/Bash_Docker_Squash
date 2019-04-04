#Docker Command
DOCKER="docker"

clear

#Current Container Name that is being used to Squash into a Final Image
echo "####################################################"
echo "TYPE THE NAME OF THE CONTAINER TO COMMIT/SQUASH"
echo "####################################################"
read CONTAINER

clear

#Docker Repository to Associate Final Image with
echo "####################################################"
echo "TYPE THE NAME OF THE REPOSITORY TO COMMIT TO"
echo "####################################################"
read REPOSITORY

clear

#Docker Tag to Associate Final Image with
echo "####################################################"
echo "TYPE THE NAME OF THE TAG TO COMMIT TO"
echo "####################################################"
read TAG

clear 

#Final Image Name after work is done
IMAGE_TO_BUILD="$REPOSITORY:$TAG"

TEMP_DIRECTORY="/opt/"

#Intermediary Image Name for Raw, Flattened Container Filesystem Export
IMAGE_TO_BUILD_RAW=${IMAGE_TO_BUILD}_raw

#Dynamic Dockerfile that Contains Image Configuration
DYNAMIC_DOCKER_FILE_PATH=$(mktemp --tmpdir="$TEMP_DIRECTORY")

#Container Filesystem that is flattened but does not have Docker configurations attached
CONTAINER_EXPORT_PATH=$(mktemp --tmpdir="$TEMP_DIRECTORY")

#Image Export that Contains the Container Filesystem and the generated Dockerfile Configurations
IMAGE_EXPORT_PATH=$(mktemp --tmpdir="$TEMP_DIRECTORY")

outputArray()
{
    VARIABLE_RAW_ARRAY_TO_PARSE="$1"
    PREFIX="$2"

    declare -a TEMP_ARRAY
    TEMP_ARRAY=($VARIABLE_RAW_ARRAY_TO_PARSE)
    for ITEM in "${TEMP_ARRAY[@]}"
    do
            if [ -n "${ITEM}" ]; then
                VARIABLE_OUTPUT="$PREFIX"
                VARIABLE_OUTPUT+="$ITEM"
                echo "$VARIABLE_OUTPUT"
            fi
    done
}

getDockerInspectionValues()
{
    VARIABLE_DOCKER_IMAGE_REPO_TAG="$1"
    VARIABLE_DOCKER_INSPECTION_VALUE="$2"
    VARIABLE_INSPECTION_VALUE_DOCKERFILE_PREFIX="$3"

    VARIABLE_FORMAT_VARIABLE_ARRAY="{{range $VARIABLE_DOCKER_INSPECTION_VALUE}}{{println .}}{{end}}"
    VARIABLE_FORMAT_VARIABLE_OBJECT="{{println $VARIABLE_DOCKER_INSPECTION_VALUE}}"

    VARIABLE_DOCKER_INSPECTION_OUTPUT=$(docker inspect --format="$VARIABLE_FORMAT_VARIABLE_ARRAY" "$VARIABLE_DOCKER_IMAGE_REPO_TAG" 2>/dev/null)
    
    if [ "$?" == "1" ]; then
        #Object was not array and failed the GO formatting
        #We do this because there is no way to determine what kind of type the object is in 
        #the current docker implementation of GO for this command
        VARIABLE_DOCKER_INSPECTION_OUTPUT=$(docker inspect --format="$VARIABLE_FORMAT_VARIABLE_OBJECT" "$VARIABLE_DOCKER_IMAGE_REPO_TAG" 2>/dev/null)
    fi

    outputArray "$VARIABLE_DOCKER_INSPECTION_OUTPUT" "$VARIABLE_INSPECTION_VALUE_DOCKERFILE_PREFIX"
}

getDockerInspectionValues_AsJson()
{
    VARIABLE_DOCKER_IMAGE_REPO_TAG=$1
    VARIABLE_INSPECTION_VALUE=$2
    VARIABLE_INSPECTION_VALUE_DOCKERFILE_PREFIX=$3

    VARIABLE_FORMAT_VARIABLE_OBJECT="{{json $VARIABLE_INSPECTION_VALUE}}"

    VARIABLE_DOCKER_INSPECTION_OUTPUT=$VARIABLE_INSPECTION_VALUE_DOCKERFILE_PREFIX
    VARIABLE_DOCKER_INSPECTION_OUTPUT+=$(docker inspect --format="$VARIABLE_FORMAT_VARIABLE_OBJECT" "$VARIABLE_DOCKER_IMAGE_REPO_TAG" 2>/dev/null)

    echo $VARIABLE_DOCKER_INSPECTION_OUTPUT
}

getDockerInspectionValues_RawOutput()
{
    VARIABLE_DOCKER_IMAGE_REPO_TAG=$1
    VARIABLE_INSPECTION_VALUE=$2
    VARIABLE_INSPECTION_VALUE_DOCKERFILE_PREFIX=$3

    VARIABLE_FORMAT_VARIABLE_OBJECT="{{ $VARIABLE_INSPECTION_VALUE }}"

    VARIABLE_DOCKER_INSPECTION_OUTPUT=$VARIABLE_INSPECTION_VALUE_DOCKERFILE_PREFIX
    VARIABLE_DOCKER_INSPECTION_OUTPUT+=$(docker inspect --format="$VARIABLE_FORMAT_VARIABLE_OBJECT" "$VARIABLE_DOCKER_IMAGE_REPO_TAG" 2>/dev/null)

    echo $VARIABLE_DOCKER_INSPECTION_OUTPUT
}

getDockerInspectionValues_Healthcheck()
{
    VARIABLE_DOCKER_IMAGE_REPO_TAG=$1

    VARIABLE_DOCKER_INSPECTION_OUTPUT="HEALTHCHECK "
    VARIABLE_DOCKER_INSPECTION_OUTPUT+=$(docker inspect --format="{{ .Config.Healthcheck.Test }}" "$VARIABLE_DOCKER_IMAGE_REPO_TAG" 2>/dev/null)

    VARIABLE_DOCKER_INSPECTION_OUTPUT="${VARIABLE_DOCKER_INSPECTION_OUTPUT/[/}" 
    VARIABLE_DOCKER_INSPECTION_OUTPUT="${VARIABLE_DOCKER_INSPECTION_OUTPUT/]/}" 
    VARIABLE_DOCKER_INSPECTION_OUTPUT="${VARIABLE_DOCKER_INSPECTION_OUTPUT/CMD-SHELL/CMD}" 
    
    echo $VARIABLE_DOCKER_INSPECTION_OUTPUT
}

exportContainer()
{
	$DOCKER export --output $CONTAINER_EXPORT_PATH $CONTAINER
}

importRawImage()
{
	DELETE_FILE_AFTER=$1
    
    $DOCKER import "$CONTAINER_EXPORT_PATH" $IMAGE_TO_BUILD_RAW

    if [ "$DELETE_FILE_AFTER" == "true" ]; then
        rm -f "$CONTAINER_EXPORT_PATH"
    fi
}

buildImage()
{
    truncate --size=0 "$DYNAMIC_DOCKER_FILE_PATH"

	echo "Dynamic Docker File located at $DYNAMIC_DOCKER_FILE_PATH"

    #Get the image the container is based on
    CONTAINER_IMAGE_ID=$(getDockerInspectionValues $CONTAINER ".Image" "")
    
    echo "FROM $IMAGE_TO_BUILD_RAW" >> "$DYNAMIC_DOCKER_FILE_PATH"
    getDockerInspectionValues $CONTAINER_IMAGE_ID ".Config.User" "USER " >> "$DYNAMIC_DOCKER_FILE_PATH"
    getDockerInspectionValues $CONTAINER_IMAGE_ID ".Config.Env" "ENV " >> "$DYNAMIC_DOCKER_FILE_PATH"
    getDockerInspectionValues $CONTAINER_IMAGE_ID ".Config.WorkingDir" "WORKDIR " >> "$DYNAMIC_DOCKER_FILE_PATH"
    getDockerInspectionValues_Healthcheck $CONTAINER_IMAGE_ID >> "$DYNAMIC_DOCKER_FILE_PATH"
    getDockerInspectionValues_AsJson $CONTAINER_IMAGE_ID ".Config.Cmd" "CMD " >> "$DYNAMIC_DOCKER_FILE_PATH"
	
	DOCKER_BUILD_CONTEXT_FOLDER=$(mktemp -d --tmpdir="$TEMP_DIRECTORY")

	$DOCKER build $DOCKER_BUILD_CONTEXT_FOLDER --compress --file "$DYNAMIC_DOCKER_FILE_PATH" --tag $IMAGE_TO_BUILD
	
	#Save Dat HD Space
	$DOCKER rmi $IMAGE_TO_BUILD_RAW
}

exportImage()
{
	$DOCKER save --output $IMAGE_EXPORT_PATH $IMAGE_TO_BUILD
}

cleanUp()
{
    rm -f $DYNAMIC_DOCKER_FILE_PATH
    rm -f $CONTAINER_EXPORT_PATH
    rm -f $IMAGE_EXPORT_PATH
    docker image prune --force
    docker volume prune --force
    docker network prune --force
}

main()
{
    echo "Exporting Container..."
	exportContainer 

    echo "Importing Raw Image..."
	importRawImage "true"

    echo "Building New Image..."
	buildImage

    #echo "Exporting New Image..."
	#exportImage

    echo "Cleaning up..."
	cleanUp
}

main
