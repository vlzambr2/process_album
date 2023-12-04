use FileSystem;
use Subprocess;
use Set;

/* album provisioning */
config const num_tracks: int;
config var flac_path: string;
const MUSIC_DIR = "/clusterfs/music/";

const flac_not_given: bool = flac_path.isEmpty();

proc provisionAlbumCmd(flac_path: string, r: range(?)) {
	var chunk: set(string);
	for e in r {
		var track = e:string;
		chunk.add(track);
	}
	var chunk_arr = chunk.toArray();

	var load_cmd = ["sudo", "abcde", "-d", flac_path, "-o", "wav"];
	
	var total_size = load_cmd.size + chunk_arr.size;
	var load_chunk_cmd: [0..<total_size] string;
	load_chunk_cmd[0..<load_cmd.size] = load_cmd;
	load_chunk_cmd[load_cmd.size..] = chunk_arr;

	return load_chunk_cmd;
}


/* directory inspecting to find new file */ 
proc createDirContentsSet(dir: string) {
	var dir_contents: set(string);

	for e in listdir(dir) {
		dir_contents.add(e);
	}
	
	return dir_contents;
}

if flac_not_given {
	var music_dir_before: set(string) = createDirContentsSet(MUSIC_DIR);

	/* single command on 1st locale to rip entire CD into flac w/ embedded cuesheet */
	var load_entire_disk_sub = spawn(["sudo", "abcde", "-1", "-o", "flac", "-a", "default,cue"]);
	load_entire_disk_sub.wait();

	var music_dir_after: set(string) = createDirContentsSet(MUSIC_DIR);

	var new_flac_name_all = (music_dir_after - music_dir_before).toArray().first.split(".");	
	var new_flac_name: string = new_flac_name_all[0];

	writeln("Found .flac file (hopefully) named: ", new_flac_name);

	flac_path = MUSIC_DIR + new_flac_name + ".flac";
}
writeln("flac_path: ", flac_path);

var music_dir_before = createDirContentsSet(MUSIC_DIR);
coforall loc in Locales {
	writeln("In coforall loop on Locale", loc.id);
	var load_chunk_sub = spawn(provisionAlbumCmd(flac_path, loc.id+1..num_tracks by numLocales));
	writeln("Deployed load_chunk_sub on Locale", loc.id);
	load_chunk_sub.wait();
}
var music_dir_after = createDirContentsSet(MUSIC_DIR);

if flac_not_given {
	var new_artist_dir = (music_dir_after - music_dir_before).toArray().first + "/";
	var flac_path_split = flac_path.split("/");
	var flac_name_split = flac_path_split.last.split(".");
	var new_album_dir = flac_name_split.first;
	
	var move_flac = spawn(["sudo", "mv", flac_path, MUSIC_DIR + new_artist_dir + new_album_dir]);
	move_flac.wait();
	
	var move_flac_cue = spawn(["sudo", "mv", flac_path + ".cue", MUSIC_DIR + new_artist_dir + new_album_dir]);
	move_flac_cue.wait();

	writeln(".flac files moved to: ", MUSIC_DIR + new_artist_dir + new_album_dir);
}

