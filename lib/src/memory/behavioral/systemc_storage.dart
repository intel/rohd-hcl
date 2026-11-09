// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// systemc_storage.dart
// Shared sparse four-state storage emitted by behavioral SystemC exporters.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

/// C++ storage shared by generated behavioral models in one translation unit.
///
/// Families own address interpretation, missing-word values, and timing. The
/// storage normalizes Z to X on writes and copies its state for snapshots.
const systemCSparseStorageDefinition = '''
#ifndef ROHD_HCL_SYSTEMC_SPARSE_STORAGE_DEFINED
#define ROHD_HCL_SYSTEMC_SPARSE_STORAGE_DEFINED
#include <systemc>
#include <map>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>
template<int Width>
class RohdHclSystemCSparseStorage {
public:
  using word = sc_dt::sc_lv<Width>;
  struct uncertain_write { std::string pattern; word affected; };
  struct image {
    std::map<std::string, word> entries;
    std::vector<uncertain_write> uncertain;
  };

  bool contains(const std::string& address) const {
    return state_.entries.find(address)!=state_.entries.end();
  }
  word read(const std::string& address, const word& absent) const {
    auto it=state_.entries.find(address);
    if(it!=state_.entries.end()) return it->second;
    word result=absent;
    for(const auto& write:state_.uncertain)
      if(matches(write.pattern,address)) apply(result,write.affected);
    return result;
  }
  void write(const std::string& address, word value) {
    normalize(value);
    state_.entries.insert_or_assign(address,value);
  }
  void write_uncertain(const std::string& pattern, const word& affected) {
    validate(pattern,affected);
    image next=state_;
    for(auto& entry:next.entries)
      if(matches(pattern,entry.first)) apply(entry.second,affected);
    next.uncertain.push_back({pattern,affected});
    state_=std::move(next);
  }
  void erase(const std::string& address) { state_.entries.erase(address); }
  void clear() { state_.entries.clear(); state_.uncertain.clear(); }
  image snapshot() const { return state_; }
  void restore(const image& saved) {
    image next=saved;
    for(auto& entry:next.entries) normalize(entry.second);
    for(const auto& write:next.uncertain) validate(write.pattern,write.affected);
    state_=std::move(next);
  }
private:
  image state_;
  static void normalize(word& value) {
    for(int bit=0;bit<Width;++bit)
      if(value[bit]==sc_dt::SC_LOGIC_Z) value[bit]=sc_dt::SC_LOGIC_X;
  }
  static void validate(const std::string& pattern, const word& affected) {
    bool unknown=false;
    for(char c:pattern) {
      if(c=='X' || c=='Z') unknown=true;
      else if(c!='0' && c!='1')
        throw std::invalid_argument("Invalid symbolic address");
    }
    if(!unknown || !affected.is_01())
      throw std::invalid_argument("Invalid symbolic write");
  }
  static bool matches(const std::string& pattern, const std::string& address) {
    if(pattern.size()!=address.size()) return false;
    for(std::size_t i=0;i<pattern.size();++i)
      if(pattern[i]!='X' && pattern[i]!='Z' && pattern[i]!=address[i])
        return false;
    return true;
  }
  static void apply(word& value, const word& affected) {
    for(int bit=0;bit<Width;++bit)
      if(affected[bit]==sc_dt::SC_LOGIC_1) value[bit]=sc_dt::SC_LOGIC_X;
  }
};
#endif
''';
