import os
configfile: "config.yaml"
# ------ prepare the count, fragment and bias file ---------

rule prepare:
    #prepare all input files for fit-Hi-C
    input: 
        config["inputfile"]
    output:
        #count: config["dirs"]["counts"]/config["library"]_{res}_fithic.contactCounts.gz || count file don't have explicit output name
        fragments = os.path.join(config["dirs"]["fragments"], config["library"] + "_{res}_frag.gz"),
        counts_dummy = touch( os.path.join(config["dirs"]["counts"], config["library"] + "_{res}_fithic.contactCounts.gz.dummy") )
        #fragments = "{}/{}_{res}_frag.gz".format(config["dirs"]["fragments"], config["library"])
        #fragments = "{frag_dir}/{library}_{res}_frag.gz"
    conda:
        "envs/magma.yaml"
    params:
        resolution = "{res}",
        library = config["library"] + "_{res}"
    log:
        os.path.join(config["dirs"]["logs"], config["library"]+"_{res}.log") 
    shell:
        '''
        sh {config[software][valid2counts]} {params.resolution} {params.library} {input} {config[dirs][counts]} > {log}
        python3 {config[software][fragments]} --chrLens {config[reference][chr_len]} --resolution {params.resolution} --outFile {output.fragments} 
        ''' 
rule norm:
    input:
        #rules.prepare.output.count || only can be given directl in shell
        fragments = rules.prepare.output.fragments
    output:
        os.path.os.path.join(config["dirs"]["bias"], config["library"] + "_{res}.bias.gz") 
        #"{config['dirs']['bias']}/config['library']_{res}.bias.gz" *this  works*
        #"{bias_dir}/{library}_{res}_bias.gz"
    conda:
        "envs/magma.yaml"
    log:
        rules.prepare.log
    shell:
        '''
        python3 {config[software][bias]} -i {config[dirs][counts]}/{config[library]}_{wildcards.res}_fithic.contactCounts.gz \
        -f {input.fragments} -o {output} >> {log}
        '''    
rule pq_calc:
    #need script to generate -L from {res}
    input:
        #rules.prepare.output.count || same reason
        fragments = rules.prepare.output.fragments,
        bias = rules.norm.output
    output:
        touch(os.path.join(config["dirs"]["results"], config["library"]+"_{res}", ".dummy")) # or using directory as output
        #"{result_dir}/{library}_{res}.dummy"
    conda:
        "envs/magma.yaml"
    params:
        resolution = "{res}",
        library = config["library"] + "_{res}"
    log:
        rules.norm.log
    shell:
        '''
        fithic \
        -i {config[dirs][counts]}/{config[library]}_{wildcards.res}_fithic.contactCounts.gz\
        -f {input.fragments} \
        -t {input.bias} \
        -r {params.resolution} \
        -o {config[dirs][results]}/{config[library]}_{wildcards.res} \
        -l {params.library} \
        -x All \
        -U 100000000 \
        -v >> {log}\
        '''
rule do_prepare:
    input:
        expand(rules.prepare.output, res = config["resolution"])
rule do_norm:
    input:
        expand(rules.norm.output, res = config["resolution"])
rule All:
    input:
        #expand(rules.pq_calc.output, result_dir= result_dir, library=library, res = [40000, 80000, 160000, 320000, 640000, 1280000])
        expand(rules.pq_calc.output, res = config["resolution"])