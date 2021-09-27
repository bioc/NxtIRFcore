/* ReadBlockProcessor_CoverageBlocks.cpp Reads coverage blocks and fragment coverage

Copyright (C) 2021 Alex Chit Hei Wong
Copyright (C) 2016 William Ritchie
  - original: https://github.com/williamritchie/IRFinder/tree/IRFinder-1.3.1)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.  */

#include "ReadBlockProcessor_CoverageBlocks.h"

void CoverageBlocks::loadRef(std::istringstream &IN) {
	std::string myLine;
	std::string myField;
	myLine.reserve(1000);
	myField.reserve(100);

	//string s_chr;
	string sLengths;
	string sOffsets;
	//unsigned int i_start;
	//unsigned int i_end;
	unsigned int i_block_start;
	unsigned int i_block_end;
	unsigned int i_segments;
	//string s_keydata;
	string s_dir;
	//s_keydata.reserve(400);
	BEDrecord BEDrec;

	// std::map<string, std::vector<std::pair<unsigned int, unsigned int>> > temp_segments;

	while (!IN.eof()) {
		getline(IN, myLine);
		std::istringstream lineStream;
		std::istringstream lensStream;
		std::istringstream offsetsStream;
		lineStream.str(myLine);

		getline(lineStream, BEDrec.chrName, '\t');		//Chr
		getline(lineStream, myField, '\t');		//BED Start
		BEDrec.start = stoul(myField);
		getline(lineStream, myField, '\t');		//BED End
		BEDrec.end = stoul(myField);
		getline(lineStream, BEDrec.name, '\t');	//BED entry name.
				/* This is separated by '/' -- do we actually need to split any of this for our calculations? Maybe - final output should probably be BED like, showing start,end pos of the original BED blocks/intron rather than the excl trimmed form. */
		lineStream.ignore( numeric_limits<streamsize>::max(), '\t' ); //Score /* Throw away the next field */
		getline(lineStream, s_dir, '\t');		//Block direction +/-/.
		BEDrec.direction = (s_dir == "+");
		lineStream.ignore( numeric_limits<streamsize>::max(), '\t' );	//Thick BED Start
		lineStream.ignore( numeric_limits<streamsize>::max(), '\t' );	//Thick BED End
		lineStream.ignore( numeric_limits<streamsize>::max(), '\t' );	//BED Colour
		getline(lineStream, myField, '\t');		//BED block count
		i_segments = stoul(myField);
		getline(lineStream, sLengths, '\t');	//Comma separated lengths.  
		lensStream.str(sLengths);

		if (IN.eof()) {
			//ie: we don't have a complete line here -- maybe because the last line was just a "\n".
			break;
			// TODO -- better use eof() / fail().
		}
		getline(lineStream, sOffsets, '\t');	//Comma separated offsets.
		offsetsStream.str(sOffsets);

		// The Blocked BED records - simply in a vector per Chromosome - sorted as input. (this may need a storage class for these records, optionally that storage class could also do the processing at output stage)
		// It would be more efficient to store on reading directly into the final location in the BEDrecords vector ..
		// Optimisation unnecessary, this only runs at startup.

		BEDrec.blocks.clear();
		//Process the discovered blocks to work out the regions we need to measure & store coverage depth.
		for (int i = i_segments; i > 0; i--) {
			getline(offsetsStream, myField, ',');
			i_block_start = BEDrec.start + stoul(myField);
			getline(lensStream, myField, ',');
			i_block_end = i_block_start + stoul(myField);
			BEDrec.blocks.push_back(std::make_pair( i_block_start, i_block_end ));
			// temp_segments[BEDrec.chrName].push_back(std::make_pair( i_block_start, i_block_end ) ); 
		}		
		BEDrecords.push_back(BEDrec);
	}
	// Read from file complete.

}

void CoverageBlocks::ChrMapUpdate(const std::vector<chr_entry> &chrmap) {
  for (unsigned int i = 0; i < chrmap.size(); i++) {
    chrs.push_back(chrmap.at(i));
  }
}


void CoverageBlocks::ProcessBlocks(const FragmentBlocks &blocks) {
  // do nothing
}

// Using FragmentsMap
void CoverageBlocks::fillHist(std::map<unsigned int,unsigned int> &hist, const unsigned int &refID, 
    const std::vector<std::pair<unsigned int,unsigned int>> &blocks, 
    const FragmentsMap &FM, bool debug) const{
      
	for (auto it_blocks=blocks.begin(); it_blocks!=blocks.end(); it_blocks++) {
		FM.updateCoverageHist(hist, it_blocks->first, it_blocks->second, 2, refID, debug);
	}
}

void CoverageBlocks::fillHist(std::map<unsigned int,unsigned int> &hist, const unsigned int &refID, 
    const std::vector<std::pair<unsigned int,unsigned int>> &blocks, bool direction, 
    const FragmentsMap &FM, bool debug) const{
      
	for (auto it_blocks=blocks.begin(); it_blocks!=blocks.end(); it_blocks++) {
		FM.updateCoverageHist(hist, it_blocks->first, it_blocks->second, direction ? 1 : 0, refID, debug);
	}
}


double CoverageBlocks::meanFromHist(const std::map<unsigned int,unsigned int> &hist) const {
	unsigned long long total = 0;
	unsigned int count = 0;
	
	for (auto h : hist) {
		total += h.first * h.second;
		count += h.second;
	}
	return (total/(double)count);
}

double CoverageBlocks::coverageFromHist(const std::map<unsigned int,unsigned int> &hist) const {
	if (hist.find(0) == hist.end()) {
		return 1.0; //No bases are at zero cover.
	}
	unsigned int count = 0;
	for (auto h : hist) {
		count += h.second;
	}
	return ((count - hist.at(0))/(double)count);
}


double CoverageBlocks::percentileFromHist(const std::map<unsigned int,unsigned int> &hist, unsigned int percentile) const {
	unsigned int size = 0;
	for (auto h : hist) {
		size += h.second;
	}
	double percentile_frac = (size + 1)*(double)percentile/100;
	unsigned int percentile_index = percentile_frac;  //round down
	percentile_frac = percentile_frac - percentile_index;

	unsigned int count = 0;
	for (auto h = hist.begin(); h != hist.end(); h++) {
		count += h->second;
		if (count >= percentile_index) {
			if (count > percentile_index || percentile_frac == 0) {
				return h->first;
			}else{
				double ret = h->first - (percentile_frac * h->first);
				h++;
				ret += (percentile_frac * h->first);
				return ret;
			}
		}
	}
	return std::numeric_limits<double>::quiet_NaN();
}

double CoverageBlocks::trimmedMeanFromHist(const std::map<unsigned int,unsigned int> &hist, unsigned int centerPercent, bool debug) const {
	unsigned int size = 0;
	for (auto h : hist) {
		size += h.second;
    if(debug) cout << h.first << '\t' << h.second << '\n';
	}
	double skip_d = (double)size * ((100.0 - (double)centerPercent)/2.0) / 100.0; 
	unsigned int skip = floor(skip_d);
	
	unsigned long long total = 0;
	unsigned int count = 0;
	
	for (auto h : hist) {
		if (count + h.second > size - skip) {
			// This bar will enter the max skip section.
			if (count > skip) {
				//already inside target range
				total += h.first * (size - skip - count);
			}else{
				//yet to enter target range
				return h.first; //(all relevant numbers are the same for this mean)
			}
			break;
		}
		if (count > skip) {
			// Start and stop are fully inside the counted section.
			total += h.first * h.second;
		}else if (count + h.second > skip) {
			// We leave the min skip section and use some of the size of this hist bar.
			total += h.first * (count + h.second - skip);
		}
		count += h.second;
	}
	return ((double)total/(size-2*skip));
}



int CoverageBlocks::WriteOutput(std::string& output, const FragmentsMap &FM) const {

// This output function will be generic -- outputting Chr/Start/Stop/Name/Dir/ Score - Mean50 (that bit probably cmd line customisable).
// The output we need will be in the extended class.
    std::ostringstream oss;
  unsigned int refID = 0;
	for (std::vector<BEDrecord>::const_iterator it_BED=BEDrecords.begin(); it_BED!=BEDrecords.end(); it_BED++) {
		unsigned int len=0;
		for (std::vector<std::pair<unsigned int,unsigned int>>::const_iterator it_blocks=it_BED->blocks.begin(); it_blocks!= it_BED->blocks.end(); it_blocks++) {
			len += (it_blocks->second - it_blocks->first);
		}
		std::map<unsigned int,unsigned int> hist;
		fillHist(hist, refID, it_BED->blocks, FM);

		unsigned int histPositions = 0;
		for (auto h : hist) {
			histPositions += h.second;
			//DEBUGGING
			oss << h.first << "\t" << h.second << "\n";
		}

		//oss << "\n";
		oss << it_BED->chrName << "\t" << it_BED->start << "\t" << it_BED->end << "\t" << (it_BED->end - it_BED->start) << "\t" << histPositions << "\t" << hist.size() << "\t" << trimmedMeanFromHist(hist, 50)  << "\t" << trimmedMeanFromHist(hist, 20) << "\t" << coverageFromHist(hist) << "\t" << meanFromHist(hist) << "\t" << it_BED->direction << "\t" << it_BED->name << "\n";
		oss << percentileFromHist(hist, 25) << "\t" << percentileFromHist(hist, 50) << "\t" << percentileFromHist(hist, 75) << "\t" << "\n";
	}
	output = oss.str();
	return 0;
}

void CoverageBlocksIRFinder::Combine(CoverageBlocksIRFinder &child) {
  // do nothing; combining not necessary
}

int CoverageBlocksIRFinder::WriteOutput(std::string& output, std::string& QC, 
    const JunctionCount &JC, const SpansPoint &SP, const FragmentsMap &FM, 
     int n_threads, int directionality) const {
  
  if(n_threads < 1) return(-1);
  
  std::ostringstream oss_title; std::ostringstream oss_qc; 
  std::vector<std::ostringstream> oss(n_threads);
  
	// Custom output function - related to the IRFinder needs
  if(directionality == 0) {
    oss_title << "Nondir_Chr\tStart\tEnd\tName\tNull\tStrand\tExcludedBases\tCoverage\tIntronDepth\tIntronDepth25Percentile\tIntronDepth50Percentile\tIntronDepth75Percentile\tExonToIntronReadsLeft\tExonToIntronReadsRight\tIntronDepthFirst50bp\tIntronDepthLast50bp\tSpliceLeft\tSpliceRight\tSpliceExact\tIRratio\tWarnings\n";
  } else {
    oss_title << "Dir_Chr\tStart\tEnd\tName\tNull\tStrand\tExcludedBases\tCoverage\tIntronDepth\tIntronDepth25Percentile\tIntronDepth50Percentile\tIntronDepth75Percentile\tExonToIntronReadsLeft\tExonToIntronReadsRight\tIntronDepthFirst50bp\tIntronDepthLast50bp\tSpliceLeft\tSpliceRight\tSpliceExact\tIRratio\tWarnings\n";
  }      
	// unsigned int recordNumber = 0;
	// IRBurden calculations
	double ID_clean = 0.0;
	double ID_KE = 0.0;
	double ID_AS = 0.0;
	std::string KE = "known-exon";
	
  unsigned int n_jobs = 1 + (BEDrecords.size() / n_threads);
  // cout << "n_jobs = " << n_jobs << ", BEDrecords.size() = " << BEDrecords.size() << '\n';

#ifdef _OPENMP
  #pragma omp parallel for
#endif  
  for(unsigned int i = 0; i < (unsigned int)n_threads; i++) {
    unsigned int refID = 0;
    std::string cur_chr = "";
    
    for(unsigned int j = i * n_jobs; j < (i+1) * n_jobs && j < BEDrecords.size(); j++) {
      auto BEDrec = BEDrecords.begin() + j;

      if ((directionality != 0 && (0 == BEDrec->name.compare(0, 4, "dir/"))) || (directionality == 0 && (0 == BEDrec->name.compare(0, 3, "nd/")))) {
        try {
          unsigned int intronStart;
          unsigned int intronEnd;
          unsigned int exclBases;
          double intronTrimmedMean;
          double coverage;
          bool measureDir;
          unsigned int JCleft;
          unsigned int JCright;
          unsigned int JCexact;
          unsigned int SPleft;
          unsigned int SPright;

          std::string s_buffer;
          std::string s_name;
          std::string s_ID;
          std::string s_clean;

          std::istringstream lineStream;
          lineStream.str(BEDrec->name);
          lineStream.ignore( numeric_limits<streamsize>::max(), '/' );
          getline(lineStream, s_name, '/');
          getline(lineStream, s_ID, '/');
          lineStream.ignore( numeric_limits<streamsize>::max(), '/' );
          lineStream.ignore( numeric_limits<streamsize>::max(), '/' );
          getline(lineStream, s_buffer, '/');
          intronStart = stol(s_buffer);
          getline(lineStream, s_buffer, '/');
          intronEnd = stol(s_buffer);
          lineStream.ignore( numeric_limits<streamsize>::max(), '/' );
          getline(lineStream, s_buffer, '/');
          exclBases = stol(s_buffer);
          getline(lineStream, s_clean, '/');

    //1       860574  861258  nd/SAMD11/ENSG00000187634/+/2/860569/861301/732/121/anti-over   0       +       860574  861258  255,0,0 2       538,73  0,611
    //1       860574  861296  dir/SAMD11/ENSG00000187634/+/2/860569/861301/732/83/clean       0       +       860574  861296  255,0,0 2       538,111 0,611

          if(0 != BEDrec->chrName.compare(0, BEDrec->chrName.size(), cur_chr)) {
            cur_chr = BEDrec->chrName;
            auto it = find_if(chrs.begin(), chrs.end(), 
              [&cur_chr](const chr_entry& obj) {return obj.chr_name == cur_chr;});
            if(it != chrs.end()) {
              refID = it->refID;
            } else {
              refID = chrs.size();
            }
          }

          //eg: PHF13/ENSG00000116273/+/3/6676918/6679862/2944/10/clean
          oss.at(i) << BEDrec->chrName << "\t" << intronStart << "\t" << intronEnd << "\t" << s_name << "/" << s_ID << "/" << s_clean << "\t0\t" << ((BEDrec->direction) ?  "+" : "-" ) << "\t";

          measureDir = BEDrec->direction;
          if (directionality == -1) {
            measureDir = !BEDrec->direction;
          }
          bool debug = false;
          // bool debug = (0 == s_ID.compare(0, 23, "ENST00000269305_Intron6"));
          std::map<unsigned int,unsigned int> hist;
          if (directionality == 0) {
            fillHist(hist, refID, BEDrec->blocks, FM, debug);
          }else{
            fillHist(hist, refID, BEDrec->blocks, measureDir, FM, debug);
          }
          intronTrimmedMean = trimmedMeanFromHist(hist, 40, debug);
          coverage = coverageFromHist(hist);
          oss.at(i) << exclBases << "\t"
            << coverage << "\t"
            << intronTrimmedMean << "\t"
            << percentileFromHist(hist, 25) << "\t"
            << percentileFromHist(hist, 50) << "\t"
            << percentileFromHist(hist, 75) << "\t";

          if(s_clean.compare(0, 5, "clean") == 0) {
#ifdef _OPENMP
  #pragma omp atomic
#endif  
            ID_clean += intronTrimmedMean;				
          } else if(s_clean.find(KE) != string::npos) {
#ifdef _OPENMP
  #pragma omp atomic
#endif  
            ID_KE += intronTrimmedMean;				
          } else if(directionality == 0) {
#ifdef _OPENMP
  #pragma omp atomic
#endif  
            ID_AS += intronTrimmedMean;				
          }

          if (directionality != 0) {
            SPleft = SP.lookup(BEDrec->chrName, intronStart, measureDir);
            SPright = SP.lookup(BEDrec->chrName, intronEnd, measureDir);
            oss.at(i) << SPleft << "\t"
              << SPright << "\t";

            hist.clear();
            fillHist(hist, refID, {{intronStart + 5, intronStart + 55}}, measureDir, FM);
            oss.at(i) << trimmedMeanFromHist(hist, 40) << "\t";
            hist.clear();
            fillHist(hist, refID, {{intronEnd - 55, intronEnd - 5}}, measureDir, FM);
            oss.at(i) << trimmedMeanFromHist(hist, 40) << "\t";
            JCleft = JC.lookupLeft(BEDrec->chrName, intronStart, measureDir);
            JCright = JC.lookupRight(BEDrec->chrName, intronEnd, measureDir);
            JCexact = JC.lookup(BEDrec->chrName, intronStart, intronEnd, measureDir);
            oss.at(i) << JCleft << "\t"
              << JCright << "\t"
              << JCexact << "\t";
          }else{
            SPleft = SP.lookup(BEDrec->chrName, intronStart);
            SPright = SP.lookup(BEDrec->chrName, intronEnd);
            oss.at(i) << SPleft << "\t"
              << SPright << "\t";			

            hist.clear();
            fillHist(hist, refID, {{intronStart + 5, intronStart + 55}}, FM);
            oss.at(i) << trimmedMeanFromHist(hist, 40) << "\t";
            hist.clear();
            fillHist(hist, refID, {{intronEnd - 55, intronEnd - 5}}, FM);
            oss.at(i) << trimmedMeanFromHist(hist, 40) << "\t";
            JCleft = JC.lookupLeft(BEDrec->chrName, intronStart);
            JCright = JC.lookupRight(BEDrec->chrName, intronEnd);
            JCexact = JC.lookup(BEDrec->chrName, intronStart, intronEnd);
            oss.at(i) << JCleft << "\t"
              << JCright << "\t"
              << JCexact << "\t";
          }
          if (intronTrimmedMean == 0 && JCleft == 0 && JCright == 0) {
            oss.at(i) << "0" << "\t";
          }else if (intronTrimmedMean < 1) {
            oss.at(i) << ( coverage / (coverage + max(JCleft, JCright)) ) << "\t";
          }else{
            oss.at(i) << ( intronTrimmedMean /(intronTrimmedMean + max(JCleft, JCright)) ) << "\t";
          }
          
          // Final column -- don't try to be tri-state. Just say if it is "not ok".
          // Not ok due to:
          //	- insufficient spliced depth
          //  - insufficient exact spliced compared to in-exact spliced depth
          //  - too much variation between depths & crossings.  ... hmm, but at low depth, high probability of this failing.
          
          // Can only make a strong exclude call on spliced depth. Describe on the tool website ways to make a call for IR def true / IR def false.
  //				if (JCexact < 10 || JCexact*1.33333333 < max(JCleft, JCright) ) {
  //					oss.at(i) << "-" << "\n";
  //				}else{
  //					oss.at(i) << "ok" << "\n";
  //				}

          if (JCexact + intronTrimmedMean < 10) {
            oss.at(i) << "LowCover" << "\n";
          }else if (JCexact < 4) {
            oss.at(i) << "LowSplicing" << "\n";
          }else if (JCexact*1.33333333 < max(JCleft, JCright) ) {
            oss.at(i) << "MinorIsoform" << "\n";
          // TODO: check, logic below. Crossing should differ by more than 2 & more than 50% before a fault is called.
          }else if (  (max(SPleft, SPright) > intronTrimmedMean+2 && max(SPleft, SPright) > intronTrimmedMean*1.5 )
              || (min(SPleft, SPright)+2 < intronTrimmedMean && min(SPleft, SPright)*1.5 < intronTrimmedMean ) ){
            oss.at(i) << "NonUniformIntronCover" << "\n";
          }else{
            oss.at(i) << "-" << "\n";
          }

          
        }catch (const std::out_of_range& e) {
          #ifdef RNXTIRF
            cout << "Format error in name attribute - column 4 - of CoverageBlocks reference file. Record/line number: " << j << "\n";
          #else
            std::cerr << "Format error in name attribute - column 4 - of CoverageBlocks reference file. Record/line number: " << j << "\n";
          #endif
        }catch (const std::invalid_argument& e) {
          #ifdef RNXTIRF
            cout << "Format error in name attribute - column 4 - of CoverageBlocks reference file. Record/line number: " << j << "\n";
          #else
            std::cerr << "Format error in name attribute - column 4 - of CoverageBlocks reference file. Record/line number: " << j << "\n";
          #endif
        }
      }

    }
    
  }
  
  
	// for (auto BEDrec : BEDrecords) {
		// recordNumber++;
		// if name indicates it is a Dir/Non-dir record of interest - output it.
		// We need to separate dir&non-dir by name. (.startswith)

	// }
  
	if(directionality == 0) {
		oss_qc 	<< "Non-Directional Clean IntronDepth Sum" << "\t" << ID_clean << "\n"
						<< "Non-Directional Known-Exon IntronDepth Sum" << "\t" << ID_KE << "\n"
						<< "Non-Directional Anti-Sense IntronDepth Sum" << "\t" << ID_AS << "\n";		
	} else {
		oss_qc 	<< "Directional Clean IntronDepth Sum" << "\t" << ID_clean << "\n"
						<< "Directional Known-Exon IntronDepth Sum" << "\t" << ID_KE << "\n";
	}
	
  
  output.append(oss_title.str());
  for(unsigned int i = 0; i < (unsigned int)n_threads; i++) {
    output.append(oss.at(i).str());
  }

	QC.append(oss_qc.str());
	
	return 0;
}


void FragmentsMap::ChrMapUpdate(const std::vector<chr_entry> &chrmap) {
  std::vector< std::pair<unsigned int, int> > empty_vector;
  empty_vector.push_back(std::make_pair (0,0));
  for(unsigned int j = 0; j < 3; j++) {   
    chrName_vec_final[j].resize(0);
    chrName_vec_new[j].resize(0);
    temp_chrName_vec_new[j].resize(0);
    for (unsigned int i = 0; i < chrmap.size(); i++) {
      chrName_vec_final[j].push_back(empty_vector);
      chrName_vec_new[j].push_back(empty_vector);
      temp_chrName_vec_new[j].push_back(empty_vector);
    }
  }

  for (unsigned int i = 0; i < chrmap.size(); i++) {
    chrs.push_back(chrmap.at(i));
  }
}

void FragmentsMap::ProcessBlocks(const FragmentBlocks &blocks) {
  for (int index = 0; index < blocks.readCount; index ++) {
    //Walk each block within each read.
    for (unsigned int j = 0; j < blocks.rLens[index].size(); j++) {
      // Stranded 
      (temp_chrName_vec_new[blocks.direction].at(blocks.chr_id)).push_back(std::make_pair( blocks.readStart[index] + blocks.rStarts[index][j], 1));
      (temp_chrName_vec_new[blocks.direction].at(blocks.chr_id)).push_back(std::make_pair( blocks.readStart[index] + blocks.rStarts[index][j] + blocks.rLens[index][j], -1));

      // Unstranded 
      (temp_chrName_vec_new[2].at(blocks.chr_id)).push_back(std::make_pair( blocks.readStart[index] + blocks.rStarts[index][j], 1));
      (temp_chrName_vec_new[2].at(blocks.chr_id)).push_back(std::make_pair( blocks.readStart[index] + blocks.rStarts[index][j] + blocks.rLens[index][j], -1));
    }
  }
  frag_count += 1;
  if(frag_count % 1000000 == 0) {
    sort_and_collapse_temp();
  }
}

int FragmentsMap::sort_and_collapse_temp() {
  // Sort temp vectors and append to final:
  for(unsigned int j = 0; j < 3; j++) {
    unsigned int refID = 0;
    for (auto itChr=temp_chrName_vec_new[j].begin(); itChr!=temp_chrName_vec_new[j].end(); itChr++) {
      // sort
      if(itChr->size() > 0) {
        std::sort(
          itChr->begin(),
          itChr->end()
        );

        unsigned int loci = 0;
        int accum = 0;
        for(auto it_pos = itChr->begin(); it_pos != itChr->end(); it_pos++) {
          if(it_pos->first != loci) {
            if(accum != 0) chrName_vec_new[j].at(refID).push_back( std::make_pair(loci, accum) );
            loci = it_pos->first;
            accum = it_pos->second;
          } else {
            accum += it_pos->second;
          }
        }
        // final push
        chrName_vec_new[j].at(refID).push_back( std::make_pair(loci, accum) );

        // Clear temporary vector by swap trick
        // empty swap vector
        std::vector< std::pair<unsigned int, int> > empty_swap_vector;
        itChr->swap(empty_swap_vector);
      }      
      refID++;
    }
  }
  return(0);
}

int FragmentsMap::sort_and_collapse_final(bool verbose) {
  if(!final_is_sorted) {
    sort_and_collapse_temp();
    if(verbose)  cout << "Performing final sort of fragment maps\n";

#ifdef _OPENMP
      #pragma omp parallel for
#endif
    for(unsigned int k = 0; k < 3 * chrs.size(); k++) {
      unsigned int j = k / chrs.size();
      unsigned int i = k - (j * chrs.size());
      
        auto itChr = &chrName_vec_new[j].at(i);
        auto itDest = &chrName_vec_final[j].at(i);
        itDest->resize(0);
        // sort
        std::sort(
          itChr->begin(),
          itChr->end()
        );
        
        // Progressors
        unsigned int   loci = 0;       // Current genomic coordinate
        unsigned int   old_loci = 0;       // Current genomic coordinate
        int           depth = 0;       // Current depth of cursor
        int           old_depth = 0;  // Previous depth of cursor
        
        for(auto it_pos = itChr->begin(); it_pos != itChr->end(); it_pos++) {
          if(it_pos->first != loci) {
            if(depth != old_depth) {  
              itDest->push_back( std::make_pair(old_loci, old_depth) );
              old_depth = depth;
              old_loci = loci;
            }
            loci = it_pos->first;
          }
          // if(incremental) {
            depth += it_pos->second;
          // } else {
            // depth = it_pos->second;
          // }
          if(it_pos->first == 0) {
            old_depth = depth;  // ensure never trigger write when first time it_pos->first != loci
          }       
        }
        itDest->push_back( std::make_pair(old_loci, old_depth) );
        if(depth != old_depth) {
          itDest->push_back( std::make_pair(loci, depth) );
        }
        itChr->clear();
        
    }
    final_is_sorted = true;
  }
  return(0);
}

void FragmentsMap::Combine(FragmentsMap &child) {
  sort_and_collapse_temp();
  child.sort_and_collapse_temp();
  if(!final_is_sorted && !child.final_is_sorted) {
    for(unsigned int j = 0; j < 3; j++) {
      for(unsigned int i = 0; i < chrs.size(); i++) {
        chrName_vec_new[j].at(i).insert(chrName_vec_new[j].at(i).end(),
          child.chrName_vec_new[j].at(i).begin(), child.chrName_vec_new[j].at(i).end());
      }
    }
  } else if(final_is_sorted && child.final_is_sorted) {
    for(unsigned int j = 0; j < 3; j++) {
      for(unsigned int i = 0; i < chrs.size(); i++) {
        chrName_vec_final[j].at(i).insert(chrName_vec_final[j].at(i).end(),
          child.chrName_vec_final[j].at(i).begin(), child.chrName_vec_final[j].at(i).end());
      }
    }
    final_is_sorted = false;  // will request resort but keep incremental = false
  }
}

// updateCoverageHist from completed FragmentMap - directional:
void FragmentsMap::updateCoverageHist(std::map<unsigned int,unsigned int> &hist, unsigned int start, unsigned int end, unsigned int dir, const unsigned int &refID, bool debug) const {
  
  if(refID >= chrName_vec_final[dir].size()) {
    hist.insert({0,0});
    return;
  }
  
  auto it_chr = &chrName_vec_final[dir].at(refID);
  auto it_pos = upper_bound(
      it_chr->begin(), 
      it_chr->end(), 
      make_pair(start, 0), 
      []( std::pair<unsigned int, int> const& a, std::pair<unsigned int, int> const& b ) { 
        return a.first < b.first; 
      }
  );
  
  if(it_pos == it_chr->end()) {
    // No coverage data
    hist[0] += end - start;
    return;
  }
  while(it_pos->first > start && it_pos != it_chr->begin()) {
    it_pos--; // shouldn't matter as the first vector pair should be at coord zero
  }
  int depth = it_pos->second;
  unsigned int cursor = start;
  while(cursor < end) {
    while(it_pos->first <= cursor && it_pos != it_chr->end()) {
      it_pos++;
    }
    if(it_pos == it_chr->end()) {
      hist[(unsigned int)depth] += end - cursor;
      break;
    }
    hist[(unsigned int)depth] += min(it_pos->first, end) - cursor;
    cursor = it_pos->first;
    depth = it_pos->second;
  }
}

int FragmentsMap::WriteBinary(
    covWriter *os, bool verbose, unsigned int n_threads_to_use
) {
  if(!final_is_sorted) {
    // Perform this separately as this is now multi-threaded
    sort_and_collapse_final(verbose);   
  }
  if(verbose)  cout << "Writing COV file\n";

  os->InitializeCOV(chrs);

#ifdef RNXTIRF
  Progress p(3 * chrs.size(), verbose);
#endif
  for(unsigned int j = 0; j < 3; j++) {
    for(unsigned int i = 0; i < chrs.size(); i++) {
      unsigned int refID = chrs[i].refID;
      
      std::vector< std::pair<unsigned int, int> > * itDest;
      itDest = &chrName_vec_final[j].at(refID);
      
      os->WriteFragmentsMap(itDest, i, j, n_threads_to_use);
#ifdef RNXTIRF
      p.increment(1);
#endif
    }
  }
  
  os->WriteToFile();
  return(0);
}

int FragmentsMap::WriteOutput(std::ostream *os, 
    int threshold, bool verbose)  {

  // This is called on mappability
  // Issue is map constructs auto-sort
  // Need to put chrs and lengths into a map structure
  /*
  std::map< std::string, int32_t > chrmap;
  
  // Arrange chromosomes in same order as arranged by mapping chrs
  for(unsigned int i = 0; i < chr_names.size(); i++) {
      chrmap.insert({chr_names[i], chr_lens[i]});
  }
  // Re-push into alphabetical ordered chromosomes
  */
  
  std::vector<std::string> sort_chr_names;
  std::vector<int32_t> sort_chr_lens;
  for (auto chr = chrs.begin(); chr != chrs.end(); chr++) {
    sort_chr_names.push_back(chr->chr_name);
    sort_chr_lens.push_back(chr->chr_len);
  }

  unsigned int refID = 0;
  if(!final_is_sorted) {
    sort_and_collapse_final(verbose);
  }
  if(verbose)  cout << "Writing Mappability Exclusions\n";
  Progress p(sort_chr_names.size(), verbose);
  for(unsigned int i = 0; i < sort_chr_names.size(); i++) {
    // refID is reference ID as appears in BAM file; i is the nth chromosome as ordered in alpha order
    refID = chrs[i].refID;
    auto itChr = &chrName_vec_final[2].at(refID);
    int coverage = 0;
    bool covered = false;
    
    if (itChr->begin()->first == 0 && itChr->begin()->second > threshold) {
      covered = true;
    } else {
      // Write first coordinate
      *os << chrs[i].chr_name << "\t0\t";
    }
    for(auto it_pos = itChr->begin(); it_pos != itChr->end(); it_pos++) {
      coverage = it_pos->second;
      if(coverage > threshold) {
        if(!covered) {
          *os << it_pos->first << '\n';
          covered = true;
        }
      } else {
        if(covered) {
          *os << chrs[i].chr_name << "\t"
              << it_pos->first << "\t";
          covered = false;
        }
      }
    }
    // Write last entry
    if(!covered) {
      *os << chrs[i].chr_len << "\n";    
    }
    p.increment(1);
  }
  return 0;
}
