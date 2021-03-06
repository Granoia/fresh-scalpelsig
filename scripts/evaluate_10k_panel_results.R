# this script must be run from the ScalpelSig home directory (i.e. NOT the scripts/ directory)

source("projection_score.R")
library(optparse)

option_list = list(
	make_option(c("-t", "--tags"), type="character", default=NULL,
		help="tags, separated by comma, of panels to be evaluated (e.g. \"first_batch,second_batch,third_batch\")", metavar="character"),
	make_option(c("-a", "--activationthresh"), type="numeric", default=0.05,
		help="activation threshold for determining whether a signature is active in a sample.", metavar="numeric"),
	make_option(c("-o", "--outtag"), type="character", default="",
		help="tag for output .tsv file", metavar="character"),
	make_option(c("-r", "--randombaseline"), type="logical", default=FALSE,
		help="flag for whether to compute the random baseline. Setting to TRUE will significantly increase the run time.", metavar="logical")
);

opt_parser = OptionParser(option_list=option_list)
opt = parse_args(opt_parser)

file_tags = opt$tags
if (is.null(file_tags)) {
        stop("No file_tags recieved (command line -t ). Please supply file_tags.")
}

EVAL_MODE = "aupr"

act_thresh = opt$activationthresh
outfile_tag = opt$outtag
baseline_flag = opt$randombaseline

DEBUG_FLAG = TRUE


# given a file name as a string fn, returns a list with information about the data that generated the file
parse_sig_est_file_name <- function(fn) {
	ret = list()

	sig_chunk = regmatches(fn, regexpr("_sig[0-9]+_", fn)) # chunk of the string that looks like '_sigNN_'
	sig_chunk = sub("_sig", "", sig_chunk) # remove '_sig' from front of chunk
	sig_chunk = sub("_", "", sig_chunk) # remove trailing underscore
	sig_num = as.numeric(sig_chunk) 
	ret[["sig_num"]] = sig_num

	obj_chunk = regmatches(fn, regexpr("_obj[0-9]+_", fn))
	obj_chunk = sub("_obj", "", obj_chunk)
	obj_chunk = sub("_", "", obj_chunk)
	obj_num = as.numeric(obj_chunk) 
	ret[["obj_num"]] = obj_num

	it_chunk = regmatches(fn, regexpr("_it[0-9]+_", fn))
	it_chunk = sub("_it", "", it_chunk)
	it_chunk = sub("_", "", it_chunk)
	it_num = as.numeric(it_chunk)
	ret[["it_num"]] = it_num

	s = sub(".tsv", "", fn)
	timestamp = sub(".*obj[0-9]+_", "", s)
	ret[["timestamp"]] = timestamp

	s = sub("panel_sig_est_", "", fn)
	tag = sub("_it[0-9]+_.*", "", s)
	ret[["tag"]] = tag

	return(ret)
}


tag_ls = strsplit(file_tags, ",")[[1]]

files = character(0)
for (file_tag in tag_ls) {
	curr_files = as.character(list.files(GLOBAL_SCRIPT_PANEL_SIG_EST_DIR, pattern= paste0(".*", file_tag, ".*") ))
	files = c(files, curr_files)
	print(paste0(Sys.time(), "    found ", length(curr_files), " files containing the tag: ", file_tag))
}
print(paste0(Sys.time(), "    found ", length(files), " files in total."))

global_sig_df = load_nz_sig_estimates(norm=TRUE)
no_norm_global_sig_df = load_nz_sig_estimates(norm=FALSE)


n = length(files)
Signature = numeric(n)
Obj.Fn = numeric(n)
Iteration = numeric(n)
File.Tag = character(n)
Timestamp.Tag = character(n)
Eval.Mode = character(n)
Panel.AUPR = numeric(n)
File.Name = character(n)

MSK.IMPACT.AUPR = numeric(n)
WES.AUPR = numeric(n)
Act.Thresh = numeric(n)
Percent.Active = numeric(n)

Est.Pval = numeric(n)
Baseline.Med = numeric(n)
Baseline.Mean = numeric(n)
Baseline.Max = numeric(n)
BP.Max.File = character(n)
BP.Spearman.Med = numeric(n)
BP.Spearman.Mean = numeric(n)

Norm.Spearman = numeric(n)
MSK.N.Spearman = numeric(n)
WES.N.Spearman = numeric(n)

Raw.Spearman = numeric(n)
MSK.R.Spearman = numeric(n)
WES.R.Spearman = numeric(n)

i = 1
# loop through each file containing the 
for (f in files) {
	print(paste0(Sys.time(), "    ", i, "/", length(files))) 
	#print(f)
	info = parse_sig_est_file_name(f)
	
	Signature[i] = info[["sig_num"]]
	Obj.Fn[i] = info[["obj_num"]]
	Iteration[i] = info[["it_num"]]
	File.Tag[i] = info[["tag"]]
	Timestamp.Tag[i] = info[["timestamp"]]
	Eval.Mode[i] = EVAL_MODE
	File.Name[i] = f

	Act.Thresh[i] = act_thresh

	#print(info)

	sig_est_outfile = paste0(GLOBAL_SCRIPT_PANEL_SIG_EST_DIR, f)	

	s = sub("panel_sig_est_", "", f) # strip "panel_sig_est_" from front of the string
	
	t = sub("_[0-9]+-.*", "", s) # remove the timestamp tag and trailing '.tsv'
	t = sub("_obj[0-9]+", "", t) # remove '_objNN' from filename
	t = sub("_nwin[0-9]+", "", t) # remove "_nwinNNN" from filename
	tt_file = paste0(GLOBAL_SCRIPT_TEST_TRAIN_DIR, "test_train_", t, ".rds")
	test_train = readRDS(tt_file)
	test_set = test_train[[1]]
	
	sig_num = info[["sig_num"]]

	Percent.Active[i] = get_percent_active(sig_num, global_sig_df, act_thresh)

	msk_impact_sig_est = paste0(GLOBAL_DATA_DIR, "msk_panel_sig_est.tsv")
	wes_sig_est = paste0(GLOBAL_DATA_DIR, "gencode_exon_panel_sig_est.tsv")

	# COMPUTE AUROC / AUPR OF PANEL
	if (EVAL_MODE=="auroc") {
		result = compute_panel_auroc(sig_num, test_set, sig_est_outfile, global_sig_df, activation_thresh=act_thresh)
		
		# benchmark panel results
		msk_result = compute_panel_auroc(sig_num, test_set, msk_impact_sig_est, global_sig_df, activation_thresh=act_thresh)
		wes_result = compute_panel_auroc(sig_num, test_set, wes_sig_est, global_sig_df, activation_thresh=act_thresh)
	} else if (EVAL_MODE=="aupr") {
		result = compute_panel_aupr(sig_num, test_set, sig_est_outfile, global_sig_df, activation_thresh=act_thresh)		

		# benchmark panel results
		msk_result = compute_panel_aupr(sig_num, test_set, msk_impact_sig_est, global_sig_df, activation_thresh=act_thresh)
		wes_result = compute_panel_aupr(sig_num, test_set, wes_sig_est, global_sig_df, activation_thresh=act_thresh)
	} else {
		stop("eval_mode was something other than \'auroc\' or \'aupr\'")
	}

	Panel.AUPR[i] = result
	MSK.IMPACT.AUPR[i] = msk_result
	WES.AUPR[i] = wes_result


	#spearman computation

        panel_sp_norm = compute_panel_spearman(sig_num, test_set, sig_est_outfile, global_sig_df)
        msk_sp_norm = compute_panel_spearman(sig_num, test_set, msk_impact_sig_est, global_sig_df)
        wes_sp_norm = compute_panel_spearman(sig_num, test_set, wes_sig_est, global_sig_df)

        Norm.Spearman[i] = panel_sp_norm
        MSK.N.Spearman[i] = msk_sp_norm
        WES.N.Spearman[i] = wes_sp_norm

        panel_sp_nonorm = compute_panel_spearman(sig_num, test_set, sig_est_outfile, no_norm_global_sig_df)
        msk_sp_nonorm = compute_panel_spearman(sig_num, test_set, msk_impact_sig_est, no_norm_global_sig_df)
        wes_sp_nonorm = compute_panel_spearman(sig_num, test_set, wes_sig_est, no_norm_global_sig_df)

        Raw.Spearman[i] = panel_sp_nonorm
        MSK.R.Spearman[i] = msk_sp_nonorm
        WES.R.Spearman[i] = wes_sp_nonorm


	if (baseline_flag) {
		# random baseline computation
		print("computing baseline vec")
		baseline_vec = compute_baseline_aupr(sig_num, test_set, global_sig_df)
		print("done.")
	
		baseline_med = median(baseline_vec)
		baseline_mean = mean(baseline_vec)
		#baseline_max = max(baseline_vec)
	
	
		#max_index = which(baseline_vec == baseline_max)
		#max_bp = names(baseline_vec)[max_index]
		#BP.Max.File[i] = max_bp

		#n_better = sum(baseline_vec >= result)
		#pval = n_better / length(baseline_vec)
	
		#Est.Pval[i] = pval
		Baseline.Mean[i] = baseline_mean
		Baseline.Med[i] = baseline_med
		#Baseline.Max[i] = baseline_max

		b_spearman_vec = compute_baseline_spearman(sig_num, test_set, global_sig_df)
		b_sp_med = median(b_spearman_vec)
		b_sp_mean = mean(b_spearman_vec)

		BP.Spearman.Med[i] = b_sp_med
		BP.Spearman.Mean[i] = b_sp_mean
	}

	i = i + 1
}

results_timestamp = format(Sys.time(), "%d-%b-%Y_%H-%M")

if (baseline_flag==TRUE) {
	# results df with random baseline
	results_df = data.frame(Raw.Spearman, MSK.R.Spearman, BP.Spearman.Med, BP.Spearman.Mean, WES.R.Spearman, Panel.AUPR, Baseline.Med, Baseline.Mean,, MSK.IMPACT.AUPR, WES.AUPR, Signature, Obj.Fn, Percent.Active, Act.Thresh, Eval.Mode, File.Tag, Timestamp.Tag, File.Name)
	results_df_outfile = paste0(GLOBAL_SCRIPT_OUT, "panel_results_df_withrandbaseline_", outfile_tag, "_", results_timestamp, ".tsv")
} else {
	# results df without random baseline
	results_df = data.frame(Raw.Spearman, MSK.R.Spearman, WES.R.Spearman, Norm.Spearman, MSK.N.Spearman, WES.N.Spearman, Panel.AUPR, MSK.IMPACT.AUPR, WES.AUPR, Signature, Obj.Fn, Percent.Active, Act.Thresh, Eval.Mode, File.Tag, Timestamp.Tag, File.Name)
	results_df_outfile = paste0(GLOBAL_SCRIPT_OUT, "panel_results_df_", outfile_tag, "_", results_timestamp, ".tsv")

}

results_df = results_df[order(Signature, Obj.Fn, -Panel.AUPR), ]

write.table(results_df, file=results_df_outfile, sep="\t", quote=FALSE)
