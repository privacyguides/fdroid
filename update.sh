#!/bin/bash

declare -a gitlab_repos=()
declare -a github_repos=("PrivacyGuides/verified-apps-android:System")
declare -a actions_repos=()
declare -a pull_repos=()
declare -a apk_repos=()
declare -a anti_features=()
declare -a fastlane_repos=("PrivacyGuides/verified-apps-android:System")

if [[ ! -d fdroid/metadata ]]; then
	mkdir -p fdroid/metadata
fi

if [[ ! -d fdroid/repo ]]; then
	mkdir -p fdroid/repo
fi

for gitlab_repo in ${gitlab_repos[@]}; do
	repo=$(echo $gitlab_repo | sed 's|:.*||')
	wget -q -O latest https://gitlab.com/api/v4/projects/$(echo $repo | sed 's/\//%2F/')/releases/permalink/latest
	release=$(cat latest | sed 's/.*"tag_name":"//' | sed 's/",".*//')
	description=$(wget -q -O - https://gitlab.com/api/v4/projects/$(echo $repo | sed 's/\//%2F/') | sed 's/.*"description":"//' | sed 's/",".*//')
	changelog="$(cat latest | sed 's/.*"description":"//' | sed 's/",".*//' | sed -z 's/\\n/\n/g')"
	url=$(cat latest | sed 's/.*"assets":{//' | sed 's/},".*//' | sed 's/.apk.*//' | sed 's/.*"direct_asset_url":"//' | sed 's/".*//')
	asset=$(cat latest | sed 's/.*"assets":{//' | sed 's/},".*//' | sed 's/.apk.*//' | sed 's/.*"name":"//' | sed 's/".*//')

	wget -q -O fdroid/repo/$asset $url

	name=$(aapt dump badging fdroid/repo/$(echo "$asset" | sed 's/apkaa/apk/') | grep application-label: | sed "s/application-label:'//" | sed "s/'.*//")
	version=$(aapt dump badging fdroid/repo/$(echo "$asset" | sed 's/apkaa/apk/') | grep versionCode | sed "s/.*versionCode='//" | sed "s/'.*//")
	id=$(aapt dump badging fdroid/repo/$(echo "$asset" | sed 's/apkaa/apk/') | grep package:\ name | sed "s/package: name='//" | sed "s/'.*//")

	for anti_feature in ${anti_features[@]}; do
		if [[ $(echo $anti_feature | sed 's|:.*||') == $repo  ]]; then
			if [[ ! -f fdroid/metadata/$id.yml ]]; then
				echo "AntiFeatures:" | tee fdroid/metadata/$id.yml
			fi

			if [[ ! $(cat fdroid/metadata/$id.yml | grep $anti_feature) == $anti_feature ]]; then
				echo "    - $(echo $anti_feature | sed 's|.*:||')" | tee -a fdroid/metadata/$id.yml
			fi
		fi
	done

	for fastlane_repo in ${fastlane_repos[@]}; do
		if [[ $fastlane_repo == $repo ]]; then
			mkdir -p fdroid/metadata/$id

			git clone https://gitlab.com/$repo

			mv $(echo $repo | sed 's/.*\///')/fastlane/metadata/android/* fdroid/metadata/$id/

			rm -rf $(echo $repo | sed 's/.*\///')

			for folder in fdroid/metadata/$id/*; do
				if [[ -d $folder/images ]]; then
					if [[ -d $folder/images/phoneScreenshots ]]; then
						mkdir -p fdroid/repo/$id/$(echo $folder | sed 's/.*\///')/phoneScreenshots

						mv $folder/images/phoneScreenshots/* fdroid/repo/$id/$(echo $folder | sed 's/.*\///')/phoneScreenshots/
					fi

					if [[ -f $folder/images/icon.png ]]; then
						mkdir -p fdroid/repo/$id/$(echo $folder | sed 's/.*\///')

						mv $folder/images/icon.png fdroid/repo/$id/$(echo $folder | sed 's/.*\///')/
					fi

					rm -rf $folder/images
				fi

				if [[ -d $folder/changelogs ]]; then
					mv $folder/changelogs/default.txt $folder/changelogs/$version.txt
				fi

				if [[ -f $folder/full_description.txt ]]; then
					mv $folder/full_description.txt $folder/description.txt
				fi

				if [[ -f $folder/short_description.txt ]]; then
					mv $folder/short_description.txt $folder/summary.txt
				fi
			done

			echo "AuthorName: $(echo $gitlab_repo | sed 's|/.*||')
Categories:
	- $(echo $gitlab_repo | sed 's|.*:||')
CurrentVersion: $release
CurrentVersionCode: $version
IssueTracker: https://gitlab.com/$repo/issues
Name: $name
SourceCode: https://gitlab.com/$repo
WebSite: https://gitlab.com/$repo
Changelog: https://gitlab.com/$repo/releases" | tee -a fdroid/metadata/$id.yml
		fi
	done

	if [[ ! -f fdroid/metadata/$id.yml ]]; then
		description=""

		if [[ -z "$description" ]]; then
			description="$name"
		else
			description="$description"
		fi

		echo "AuthorName: $(echo $gitlab_repo | sed 's|/.*||')
Categories:
	- $(echo $gitlab_repo | sed 's|.*:||')
CurrentVersion: $release
CurrentVersionCode: $version
Description: |
	$description
IssueTracker: https://gitlab.com/$repo/issues
Name: $name
SourceCode: https://gitlab.com/$repo
Summary: \"$(echo $description | cut -c 1-80)\"
WebSite: https://gitlab.com/$repo
Changelog: https://gitlab.com/$repo/releases" | tee -a fdroid/metadata/$id.yml

		mkdir -p fdroid/metadata/$id/en-US/changelogs

		echo "$changelog" | tee fdroid/metadata/$id/en-US/changelogs/$version.txt
	fi

	rm latest
done

for github_repo in ${github_repos[@]}; do
	repo=$(echo $github_repo | sed 's|:.*||')
	wget -q -O latest https://api.github.com/repos/$repo/releases/latest
	release=$(cat latest | grep tag_name | sed 's/.*tag_name\":\ \"//' | sed 's/\",//')
	changelog="$(cat latest | sed -z 's/"\n}//g' | grep body | sed 's/  "body": "//' | sed 's/",//' | sed 's/\\r//g' | sed 's/\\n/  \n/g')"
	urls=$(cat latest | grep browser_download_url | sed 's/      "browser_download_url": "//' | sed 's/"//')
	url=$(echo "$urls" | grep .apk$ | grep -v debug | grep -v arm64-v8a | grep -v armeabi-v7a | grep -v x86 | grep -v x86_64 | head -n 1)
	asset=$(echo $url | head -n 1 | sed 's/.*\///')

	wget -q -O fdroid/repo/$asset $url

	name=$(aapt dump badging fdroid/repo/$asset | grep application-label: | sed "s/application-label:'//" | sed "s/'.*//")
	version=$(aapt dump badging fdroid/repo/$asset | grep versionCode | sed "s/.*versionCode='//" | sed "s/'.*//")
	id=$(aapt dump badging fdroid/repo/$asset | grep package:\ name | sed "s/package: name='//" | sed "s/'.*//")

	for anti_feature in ${anti_features[@]}; do
		if [[ $(echo $anti_feature | sed 's|:.*||') == $repo  ]]; then
			if [[ ! -f fdroid/metadata/$id.yml ]]; then
				echo "AntiFeatures:" | tee fdroid/metadata/$id.yml
			fi

			if [[ ! $(cat fdroid/metadata/$id.yml | grep $anti_feature) == $anti_feature ]]; then
				echo "    - $(echo $anti_feature | sed 's|.*:||')" | tee -a fdroid/metadata/$id.yml
			fi
		fi
	done

	for fastlane_repo in ${fastlane_repos[@]}; do
		if [[ $fastlane_repo == $repo ]]; then
			mkdir -p fdroid/metadata/$id

			git clone https://github.com/$repo

			mv $(echo $repo | sed 's/.*\///')/fastlane/metadata/android/* fdroid/metadata/$id/

			rm -rf $(echo $repo | sed 's/.*\///')

			for folder in fdroid/metadata/$id/*; do
				if [[ -d $folder/images ]]; then
					if [[ -d $folder/images/phoneScreenshots ]]; then
						mkdir -p fdroid/repo/$id/$(echo $folder | sed 's/.*\///')/phoneScreenshots

						mv $folder/images/phoneScreenshots/* fdroid/repo/$id/$(echo $folder | sed 's/.*\///')/phoneScreenshots/
					fi

					if [[ -f $folder/images/icon.png ]]; then
						mkdir -p fdroid/repo/$id/$(echo $folder | sed 's/.*\///')

						mv $folder/images/icon.png fdroid/repo/$id/$(echo $folder | sed 's/.*\///')/
					fi

					rm -rf $folder/images
				fi

				if [[ -d $folder/changelogs ]]; then
					mv $folder/changelogs/default.txt $folder/changelogs/$version.txt
				fi

				if [[ -f $folder/full_description.txt ]]; then
					mv $folder/full_description.txt $folder/description.txt
				fi

				if [[ -f $folder/short_description.txt ]]; then
					mv $folder/short_description.txt $folder/summary.txt
				fi
			done

			echo "AuthorName: $(echo $github_repo | sed 's|/.*||')
Categories:
    - $(echo $github_repo | sed 's|.*:||')
CurrentVersion: $release
CurrentVersionCode: $version
IssueTracker: https://github.com/$repo/issues
Name: $name
SourceCode: https://github.com/$repo
WebSite: https://github.com/$repo
Changelog: https://github.com/$repo/releases" | tee -a fdroid/metadata/$id.yml
		fi
	done

	if [[ ! -f fdroid/metadata/$id.yml ]]; then
		description=""

		wget -q -O repo https://api.github.com/repos/$repo
		if [[ ! $(cat repo | grep description -m 1 | sed 's/  "description": "//' | sed 's/",//') == *null* ]]; then
			description=$(cat repo | grep description -m 1 | sed 's/  "description": "//' | sed 's/",//')
		fi

		if [[ -z "$description" ]]; then
			description="$name"
		else
			description="$description"
		fi

		echo "AuthorName: $(echo $github_repo | sed 's|/.*||')
Categories:
    - $(echo $github_repo | sed 's|.*:||')
CurrentVersion: $release
CurrentVersionCode: $version
Description: |
    $description
IssueTracker: https://github.com/$repo/issues
Name: $name
SourceCode: https://github.com/$repo
Summary: \"$(echo $description | cut -c 1-80)\"
WebSite: https://github.com/$repo
Changelog: https://github.com/$repo/releases" | tee -a fdroid/metadata/$id.yml

		mkdir -p fdroid/metadata/$id/en-US/changelogs

		echo "$changelog" | tee fdroid/metadata/$id/en-US/changelogs/$version.txt

		rm repo
	fi

	rm latest
done

for actions_repo in ${actions_repos[@]}; do
	repo=$(echo $actions_repo | sed 's|:.*||')
	wget -q -O latest https://api.github.com/repos/$repo/releases/latest
	release=$(cat latest | grep tag_name | sed 's/.*tag_name\":\ \"//' | sed 's/\",//')
	changelog="$(cat latest | sed -z 's/"\n}//g' | grep body | sed 's/  "body": "//' | sed 's/",//' | sed 's/\\r//g' | sed 's/\\n/  \n/g')"
	url=$(wget -q -O - https://api.github.com/repos/$repo/actions/artifacts | grep archive_download_url -m 1 | sed 's/      "archive_download_url": "//' | sed 's/"//' | sed 's/,//')

	curl -L -H "Authorization: Bearer $ACTIONS_TOKEN" $url -o asset

	asset=$(unzip -l asset | grep .apk$ | sed 's/.*\ //')

	unzip asset -d fdroid/repo/

	name=$(aapt dump badging fdroid/repo/$asset | grep application-label: | sed "s/application-label:'//" | sed "s/'.*//")
	version=$(aapt dump badging fdroid/repo/$asset | grep versionCode | sed "s/.*versionCode='//" | sed "s/'.*//")
	id=$(aapt dump badging fdroid/repo/$asset | grep package:\ name | sed "s/package: name='//" | sed "s/'.*//")

	for anti_feature in ${anti_features[@]}; do
		if [[ $(echo $anti_feature | sed 's|:.*||') == $repo  ]]; then
			if [[ ! -f fdroid/metadata/$id.yml ]]; then
				echo "AntiFeatures:" | tee fdroid/metadata/$id.yml
			fi

			if [[ ! $(cat fdroid/metadata/$id.yml | grep $anti_feature) == $anti_feature ]]; then
				echo "    - $(echo $anti_feature | sed 's|.*:||')" | tee -a fdroid/metadata/$id.yml
			fi
		fi
	done

	for fastlane_repo in ${fastlane_repos[@]}; do
		if [[ $fastlane_repo == $repo ]]; then
			mkdir -p fdroid/metadata/$id

			git clone https://github.com/$repo

			mv $(echo $repo | sed 's/.*\///')/fastlane/metadata/android/* fdroid/metadata/$id/

			rm -rf $(echo $repo | sed 's/.*\///')

			for folder in fdroid/metadata/$id/*; do
				if [[ -d $folder/images ]]; then
					if [[ -d $folder/images/phoneScreenshots ]]; then
						mkdir -p fdroid/repo/$id/$(echo $folder | sed 's/.*\///')/phoneScreenshots

						mv $folder/images/phoneScreenshots/* fdroid/repo/$id/$(echo $folder | sed 's/.*\///')/phoneScreenshots/
					fi

					if [[ -f $folder/images/icon.png ]]; then
						mkdir -p fdroid/repo/$id/$(echo $folder | sed 's/.*\///')

						mv $folder/images/icon.png fdroid/repo/$id/$(echo $folder | sed 's/.*\///')/
					fi

					rm -rf $folder/images
				fi

				if [[ -d $folder/changelogs ]]; then
					mv $folder/changelogs/default.txt $folder/changelogs/$version.txt
				fi

				if [[ -f $folder/full_description.txt ]]; then
					mv $folder/full_description.txt $folder/description.txt
				fi

				if [[ -f $folder/short_description.txt ]]; then
					mv $folder/short_description.txt $folder/summary.txt
				fi
			done

		echo "AuthorName: $(echo $actions_repo | sed 's|/.*||')
Categories:
    - $(echo $actions_repo | sed 's/;.*//' | sed 's|.*:||')
CurrentVersion: $release
CurrentVersionCode: $version
IssueTracker: https://github.com/$repo/issues
Name: $name
SourceCode: https://github.com/$repo
WebSite: https://github.com/$repo
Changelog: https://github.com/$repo/releases" | tee -a fdroid/metadata/$id.yml
		fi
	done

	if [[ ! -f fdroid/metadata/$id.yml ]]; then
		description=""

		wget -q -O repo https://api.github.com/repos/$repo
		if [[ ! $(cat repo | grep description -m 1 | sed 's/  "description": "//' | sed 's/",//') == *null* ]]; then
			description=$(cat repo | grep description -m 1 | sed 's/  "description": "//' | sed 's/",//')
		fi

		if [[ -z "$description" ]]; then
			description="$name"
		else
			description="$description"
		fi

		echo "AuthorName: $(echo $actions_repo | sed 's|/.*||')
Categories:
    - $(echo $actions_repo | sed 's/;.*//' | sed 's|.*:||')
CurrentVersion: $release
CurrentVersionCode: $version
Description: |
    $description
IssueTracker: https://github.com/$repo/issues
Name: $name
SourceCode: https://github.com/$repo
Summary: \"$(echo $description | cut -c 1-80)\"
WebSite: https://github.com/$repo
Changelog: https://github.com/$repo/releases" | tee -a fdroid/metadata/$id.yml

		mkdir -p fdroid/metadata/$id/en-US/changelogs

		echo "$changelog" | tee fdroid/metadata/$id/en-US/changelogs/$version.txt

		rm repo
	fi

	rm latest

	rm asset
done

for pull_repo in ${pull_repos[@]}; do
	repo=$(echo $pull_repo | sed 's|:.*||')
	pull="$(echo $pull_repo | sed 's/.*;//')"
	wget -q -O latest https://api.github.com/repos/$repo/releases/latest
	sha=$(wget -q -O - https://api.github.com/repos/$repo/pulls/$pull | grep head -A3 | grep sha | sed 's/.* "//' | sed 's/".*//')
	release=$(cat latest | grep tag_name | sed 's/.*tag_name\":\ \"//' | sed 's/\",//')
	changelog="$(cat latest | sed -z 's/"\n}//g' | grep body | sed 's/  "body": "//' | sed 's/",//' | sed 's/\\r//g' | sed 's/\\n/  \n/g')"
	url=$(wget -q -O - https://api.github.com/repos/$repo/actions/artifacts?event=pull_request | grep $sha -B10 | grep archive_download_url | sed 's/      "archive_download_url": "//' | sed 's/"//' | sed 's/,//')

	curl -L -H "Authorization: Bearer $ACTIONS_TOKEN" $url -o asset

	asset=$(unzip -l asset | grep .apk$ | sed 's/.*\ //')

	unzip asset -d fdroid/repo/

	name=$(aapt dump badging fdroid/repo/$asset | grep application-label: | sed "s/application-label:'//" | sed "s/'.*//")
	version=$(aapt dump badging fdroid/repo/$asset | grep versionCode | sed "s/.*versionCode='//" | sed "s/'.*//")
	id=$(aapt dump badging fdroid/repo/$asset | grep package:\ name | sed "s/package: name='//" | sed "s/'.*//")

	for anti_feature in ${anti_features[@]}; do
		if [[ $(echo $anti_feature | sed 's|:.*||') == $repo  ]]; then
			if [[ ! -f fdroid/metadata/$id.yml ]]; then
				echo "AntiFeatures:" | tee fdroid/metadata/$id.yml
			fi

			if [[ ! $(cat fdroid/metadata/$id.yml | grep $anti_feature) == $anti_feature ]]; then
				echo "    - $(echo $anti_feature | sed 's|.*:||')" | tee -a fdroid/metadata/$id.yml
			fi
		fi
	done

	for fastlane_repo in ${fastlane_repos[@]}; do
		if [[ $fastlane_repo == $repo ]]; then
			mkdir -p fdroid/metadata/$id

			git clone https://github.com/$repo

			mv $(echo $repo | sed 's/.*\///')/fastlane/metadata/android/* fdroid/metadata/$id/

			rm -rf $(echo $repo | sed 's/.*\///')

			for folder in fdroid/metadata/$id/*; do
				if [[ -d $folder/images ]]; then
					if [[ -d $folder/images/phoneScreenshots ]]; then
						mkdir -p fdroid/repo/$id/$(echo $folder | sed 's/.*\///')/phoneScreenshots

						mv $folder/images/phoneScreenshots/* fdroid/repo/$id/$(echo $folder | sed 's/.*\///')/phoneScreenshots/
					fi

					if [[ -f $folder/images/icon.png ]]; then
						mkdir -p fdroid/repo/$id/$(echo $folder | sed 's/.*\///')

						mv $folder/images/icon.png fdroid/repo/$id/$(echo $folder | sed 's/.*\///')/
					fi

					rm -rf $folder/images
				fi

				if [[ -d $folder/changelogs ]]; then
					mv $folder/changelogs/default.txt $folder/changelogs/$version.txt
				fi

				if [[ -f $folder/full_description.txt ]]; then
					mv $folder/full_description.txt $folder/description.txt
				fi

				if [[ -f $folder/short_description.txt ]]; then
					mv $folder/short_description.txt $folder/summary.txt
				fi
			done

		echo "AuthorName: $(echo $pull_repo | sed 's|/.*||')
Categories:
    - $(echo $pull_repo | sed 's/;.*//' | sed 's|.*:||')
CurrentVersion: $release
CurrentVersionCode: $version
IssueTracker: https://github.com/$repo/issues
Name: $name
SourceCode: https://github.com/$repo
WebSite: https://github.com/$repo
Changelog: https://github.com/$repo/releases" | tee -a fdroid/metadata/$id.yml
		fi
	done

	if [[ ! -f fdroid/metadata/$id.yml ]]; then
		description=""

		wget -q -O repo https://api.github.com/repos/$repo
		if [[ ! $(cat repo | grep description -m 1 | sed 's/  "description": "//' | sed 's/",//') == *null* ]]; then
			description=$(cat repo | grep description -m 1 | sed 's/  "description": "//' | sed 's/",//')
		fi

		if [[ -z "$description" ]]; then
			description="$name"
		else
			description="$description"
		fi

		echo "AuthorName: $(echo $pull_repo | sed 's|/.*||')
Categories:
    - $(echo $pull_repo | sed 's/;.*//' | sed 's|.*:||')
CurrentVersion: $release
CurrentVersionCode: $version
Description: |
    $description
IssueTracker: https://github.com/$repo/issues
Name: $name
SourceCode: https://github.com/$repo
Summary: \"$(echo $description | cut -c 1-80)\"
WebSite: https://github.com/$repo
Changelog: https://github.com/$repo/releases" | tee -a fdroid/metadata/$id.yml

		mkdir -p fdroid/metadata/$id/en-US/changelogs

		echo "$changelog" | tee fdroid/metadata/$id/en-US/changelogs/$version.txt

		rm repo
	fi

	rm latest

	rm asset
done

for apk_repo in ${apk_repos[@]}; do
	repo=$(echo $apk_repo | sed 's|:.*||')
	url="$(echo $apk_repo | sed 's/.*;//')"
	asset=$(echo $repo | sed 's/.*\///').apk

	wget -q -O fdroid/repo/$asset --content-disposition $url

	release=$(aapt dump badging fdroid/repo/$asset | grep versionName | sed "s/.*versionName='//" | sed "s/'.*//")

	name=$(aapt dump badging fdroid/repo/$asset | grep application-label: | sed "s/application-label:'//" | sed "s/'.*//")
	version=$(aapt dump badging fdroid/repo/$asset | grep versionCode | sed "s/.*versionCode='//" | sed "s/'.*//")
	id=$(aapt dump badging fdroid/repo/$asset | grep package:\ name | sed "s/package: name='//" | sed "s/'.*//")

	for anti_feature in ${anti_features[@]}; do
		if [[ $(echo $anti_feature | sed 's|:.*||') == $repo  ]]; then
			if [[ ! -f fdroid/metadata/$id.yml ]]; then
				echo "AntiFeatures:" | tee fdroid/metadata/$id.yml
			fi

			if [[ ! $(cat fdroid/metadata/$id.yml | grep $anti_feature) == $anti_feature ]]; then
				echo "    - $(echo $anti_feature | sed 's|.*:||')" | tee -a fdroid/metadata/$id.yml
			fi
		fi
	done

	for fastlane_repo in ${fastlane_repos[@]}; do
		if [[ $fastlane_repo == $repo ]]; then
			mkdir -p fdroid/metadata/$id

			git clone https://github.com/$repo

			mv $(echo $repo | sed 's/.*\///')/fastlane/metadata/android/* fdroid/metadata/$id/

			rm -rf $(echo $repo | sed 's/.*\///')

			for folder in fdroid/metadata/$id/*; do
				if [[ -d $folder/images ]]; then
					if [[ -d $folder/images/phoneScreenshots ]]; then
						mkdir -p fdroid/repo/$id/$(echo $folder | sed 's/.*\///')/phoneScreenshots

						mv $folder/images/phoneScreenshots/* fdroid/repo/$id/$(echo $folder | sed 's/.*\///')/phoneScreenshots/
					fi

					if [[ -f $folder/images/icon.png ]]; then
						mkdir -p fdroid/repo/$id/$(echo $folder | sed 's/.*\///')

						mv $folder/images/icon.png fdroid/repo/$id/$(echo $folder | sed 's/.*\///')/
					fi

					rm -rf $folder/images
				fi

				if [[ -d $folder/changelogs ]]; then
					mv $folder/changelogs/default.txt $folder/changelogs/$version.txt
				fi

				if [[ -f $folder/full_description.txt ]]; then
					mv $folder/full_description.txt $folder/description.txt
				fi

				if [[ -f $folder/short_description.txt ]]; then
					mv $folder/short_description.txt $folder/summary.txt
				fi
			done

			echo "AuthorName: $(echo $apk_repo | sed 's|/.*||')
Categories:
    - $(echo $apk_repo | sed 's/;.*//' | sed 's|.*:||' | sed 's/&/\ &\ /')
CurrentVersion: $release
CurrentVersionCode: $version
IssueTracker: https://github.com/$repo/issues
Name: $name
SourceCode: https://github.com/$repo
WebSite: https://github.com/$repo
Changelog: https://github.com/$repo/releases" | tee -a fdroid/metadata/$id.yml
		fi
	done

	if [[ ! -f fdroid/metadata/$id.yml ]]; then
		description="$name"

		echo "AuthorName: $(echo $apk_repo | sed 's|/.*||')
Categories:
    - $(echo $apk_repo | sed 's/;.*//' | sed 's|.*:||' | sed 's/&/\ &\ /')
CurrentVersion: $release
CurrentVersionCode: $version
Description: |
    $description
IssueTracker: https://github.com/$repo/issues
Name: $name
SourceCode: https://github.com/$repo
Summary: \"$(echo $description | cut -c 1-80)\"
WebSite: https://github.com/$repo
Changelog: https://github.com/$repo/releases" | tee -a fdroid/metadata/$id.yml

		wget -q -O latest https://api.github.com/repos/$repo/releases/latest

		release=$(cat latest | grep tag_name | sed 's/.*tag_name\":\ \"//' | sed 's/\",//')
		changelog="$(cat latest | sed -z 's/"\n}//g' | grep body | sed 's/  "body": "//' | sed 's/",//' | sed 's/\\r//g' | sed 's/\\n/\n/g')"

		mkdir -p fdroid/metadata/$id/en-US/changelogs

		echo "$changelog" | tee fdroid/metadata/$id/en-US/changelogs/$version.txt

		rm latest
	fi
done

cd fdroid

/usr/bin/fdroid update --pretty --delete-unknown --use-date-from-apk

cd ../
