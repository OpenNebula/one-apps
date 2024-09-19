#include <string>
#include <vector>
#include <map>
#include <set>
#include <sstream>
#include <iostream>
#include <iomanip>
#include <algorithm>

#include <math.h>

//******************************************************************************
//******************************************************************************
//******************************************************************************
//******************************************************************************

struct NUMANodeRequest
{
    unsigned int total_cpus;
    long long memory;

    int node_id;
    std::string cpu_ids;

    int mem_node_id;

    void to_cout()
    {
        std::cout << "[CPU] Node " << node_id << ":" << total_cpus << " (" << cpu_ids 
            << ")\t" << "[MEM] Node " << mem_node_id << ":" << memory/(1024*1024) << "G\n";
    };
};

struct HostShareRequest
{
    unsigned int vcpu;

    long long cpu;
    long long mem;
    long long disk;

    bool dedicated;

    int threads;
    int cores;
    int sockets;

    std::vector<NUMANodeRequest> nodes;
};


//******************************************************************************
//******************************************************************************
//******************************************************************************
//******************************************************************************
struct Core
{
    Core(unsigned int _i, const std::string& _c, unsigned int _vt, bool _d);

    unsigned int id;

    unsigned int free_cpus;

    unsigned int used_cpus;

    unsigned int vms_thread;

    bool dedicated;

    std::map<unsigned int, std::multiset<unsigned int> > cpus;

    std::set<unsigned int> reserved_cpus;

    void set_cpu_usage();
};

class HostShareNode
{
public:

    HostShareNode(int n, int f, std::vector<Core> &_c, long long total, long long usage, std::vector<unsigned int> dist):node_id(n), total_mem(total), mem_usage(usage),distance(dist)
    {
        for (auto it = _c.begin() ; it != _c.end() ; ++it)
        {
            cores.insert(std::make_pair((*it).id, *it));
        }

    };

    virtual ~HostShareNode(){};

    void free_capacity(unsigned int &fcpus, long long &memory, unsigned int tc)
    {
        fcpus  = 0;
        memory = total_mem - mem_usage;

        for (auto it = cores.begin(); it != cores.end(); ++it)
        {
            fcpus = fcpus + it->second.free_cpus / tc;
        }
    }

    void free_dedicated_capacity(unsigned int &fcpus, long long &memory)
    {
        fcpus  = 0;
        memory = total_mem - mem_usage;

        for (auto it = cores.begin(); it != cores.end(); ++it)
        {
            Core &c = it->second;

            if ( c.used_cpus == 0 && (c.reserved_cpus.size() < c.cpus.size()))
            {
                fcpus = fcpus + 1;
            }
        }
    }

    int allocate_dedicated_cpus(int id, unsigned int tcpus, std::string &c_s);

    int allocate_ht_cpus(int id, unsigned int tcpus, unsigned int tc,
            std::string &c_s);

    void to_cout()
    {
        std::cout << "Node: " << node_id;
        std::cout << "\tMemory: " << mem_usage / (1024*1024) << "/"
                  << total_mem / (1024*1024) << "G";
        std::cout << "\n------------------------------------------------------\n";

        for (auto it = cores.begin(); it!= cores.end(); ++it)
        {
            Core &c = it->second;

            std::cout << std::setw(4) << "[" << c.free_cpus << "]" << "( ";

            for (auto jt = c.cpus.begin(); jt != c.cpus.end(); ++jt)
            {
                std::cout << std::setw(2) << jt->first << " ";
            }

            std::cout <<") " ;
        }

        std::cout <<"\n" ;

        for (auto it = cores.begin(); it!= cores.end(); ++it)
        {
            Core &c = it->second;

            std::cout << std::setw(4) << "[" << c.free_cpus << "]" << "( ";

            for (auto jt = c.cpus.begin(); jt != c.cpus.end(); ++jt)
            {
                if ( jt->second.size() == 0 )
                {
                    std::cout << std::setw(2) << "-" << " ";
                }
                else
                {
                    std::cout << std::setw(2) << *(jt->second.begin()) << " ";
                }
            }

            std::cout <<") " ;
        }

        std::cout << std::endl;
    }

    friend class HostShareNUMA;


    //This stuct represents the hugepages available in the node
    struct HugePage
    {
        unsigned long size_kb;

        unsigned int  nr;
        unsigned int  free;

        unsigned long  usage;
        unsigned long  allocated;
    };

public:
    unsigned int node_id;

    std::map<unsigned int, struct Core> cores;
    std::map<unsigned long, struct HugePage> pages;

    unsigned int allocated_cpus;

    long long    allocated_memory;

    long long total_mem = 0;
    long long free_mem  = 0;
    long long used_mem  = 0;

    long long mem_usage = 0;

    std::vector<unsigned int> distance;
};

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

Core::Core(unsigned int _i, const std::string& _c,
        unsigned int _vt, bool _d):id(_i), vms_thread(_vt), dedicated(_d)
{
    std::stringstream cpu_s(_c);

    std::string thread;

    free_cpus = 0;

    while (getline(cpu_s, thread, ','))
    {
        unsigned int cpu_id;
        int vm_id = -1;

        if (thread.empty())
        {
            continue;
        }

        std::replace(thread.begin(), thread.end(), ':', ' ');
        std::stringstream thread_s(thread);

        if (!(thread_s >> cpu_id))
        {
            continue;
        }

        if (!(thread_s >> vm_id))
        {
            vm_id = -1;
        }

        if ( vm_id >= 0 )
        {
            cpus[cpu_id].insert(vm_id);
        }
        else if (vm_id == -2)
        {
            cpus[cpu_id];

            reserved_cpus.insert(cpu_id);
        }
        else
        {
            cpus[cpu_id];
        }
    }

    set_cpu_usage();
}

void Core::set_cpu_usage()
{
    used_cpus = 0;

    if ( dedicated )
    {
        free_cpus = 0;
        used_cpus = 1;
    }
    else
    {
        for (const auto& cpu : cpus)
        {
            used_cpus += cpu.second.size();
        }

        free_cpus = ((cpus.size() - reserved_cpus.size()) * vms_thread);

        if ( used_cpus > free_cpus )
        {
            free_cpus = 0;
        }
        else
        {
            free_cpus -= used_cpus;
        }
    }
}

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

int HostShareNode::allocate_dedicated_cpus(int id, unsigned int tcpus, std::string &c_s)
{
    std::ostringstream oss;

    for (auto vc_it = cores.begin(); vc_it != cores.end(); ++vc_it)
    {
        // ---------------------------------------------------------------------
        // Check this core can allocate a dedicated VM:
        //   2. Not all CPUs are reserved
        //   3. No other VM running in the core
        // ---------------------------------------------------------------------
        Core &core = vc_it->second;

        if ( core.reserved_cpus.size() >= core.cpus.size() )
        {
            continue;
        }

        if ( core.used_cpus != 0 )
        {
            continue;
        }

        // ---------------------------------------------------------------------
        // Allocate the core and setup allocation string
        // ---------------------------------------------------------------------
        core.cpus.begin()->second.insert(id);

        oss << core.cpus.begin()->first;

        core.dedicated = true;

        core.used_cpus = 1;
        core.free_cpus = 0;

        if ( --tcpus == 0 )
        {
            c_s = oss.str();
            break;
        }

        oss << ",";
    }

    if ( tcpus != 0 )
    {
        return -1;
    }

    c_s = oss.str();

    return 0;
}

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

int HostShareNode::allocate_ht_cpus(int id, unsigned int tcpus, unsigned int tc, std::string &c_s)
{
    std::ostringstream oss;

    for (auto vc_it = cores.begin(); vc_it != cores.end() && tcpus > 0; ++vc_it)
    {
        Core &core = vc_it->second;

        unsigned int c_to_alloc = ( core.free_cpus/tc ) * tc;

        for ( auto cpu = core.cpus.begin(); cpu != core.cpus.end() &&
                c_to_alloc > 0 ; ++cpu )
        {
            if ( cpu->second.size() >= core.vms_thread )
            {
                continue;
            }

            if ( core.reserved_cpus.count(cpu->first) == 1)
            {
                continue;
            }

            cpu->second.insert(id);

            core.free_cpus--;
            core.used_cpus++;

            c_to_alloc--;

            oss << cpu->first;

            if ( --tcpus == 0 )
            {
                break;
            }

            oss << ",";
        }
    }

    if ( tcpus != 0 )
    {
        return -1;
    }

    c_s = oss.str();

    return 0;
}

//******************************************************************************
//******************************************************************************
//******************************************************************************
//******************************************************************************

class HostShareNUMA
{
public:
    HostShareNUMA(unsigned int t, std::map<unsigned int, HostShareNode *> n):
        threads_core(t), nodes(n){};

    virtual ~HostShareNUMA(){};

    HostShareNode& get_node(unsigned int idx);

    int make_topology(HostShareRequest &sr, bool verbose);

    void to_cout()
    {
        for(auto it = nodes.begin(); it != nodes.end() ; ++it)
        {
            it->second->to_cout();
        }
    }

private:
    unsigned int threads_core;

    std::map<unsigned int, HostShareNode *> nodes;

    bool schedule_nodes(NUMANodeRequest &nr, unsigned int thr, bool dedicated);
};

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

HostShareNode& HostShareNUMA::get_node(unsigned int idx)
{
    auto it = nodes.find(idx);

    return *(it->second);
}

bool HostShareNUMA::schedule_nodes(NUMANodeRequest &nr, unsigned int threads,
        bool dedicated)
{
    std::vector<std::tuple<int,int> > cpu_fits;
    std::set<unsigned int> mem_fits;

    for (auto it = nodes.begin(); it != nodes.end(); ++it)
    {
        long long    n_fmem;
        unsigned int n_fcpu;

        if ( dedicated )
        {
            it->second->free_dedicated_capacity(n_fcpu, n_fmem);
        }
        else
        {
            it->second->free_capacity(n_fcpu, n_fmem, threads);
        }

        n_fcpu -= (it->second->allocated_cpus / threads);
        n_fmem -= it->second->allocated_memory;

        if ( n_fcpu * threads >= nr.total_cpus )
        {
            unsigned int fcpu_after =  n_fcpu * threads - nr.total_cpus;

            cpu_fits.push_back(std::make_tuple(fcpu_after, it->first));
        }

        if ( n_fmem >= nr.memory )
        {
            mem_fits.insert(it->first);
        }
    }

    //--------------------------------------------------------------------------
    // Allocate nodes using a best-fit heuristic for the CPU nodes. Closer
    // memory allocations are prioritized.
    //--------------------------------------------------------------------------
    std::sort(cpu_fits.begin(), cpu_fits.end());

    for (unsigned int hop = 0 ; hop < nodes.size() ; ++hop)
    {
        for (auto it = cpu_fits.begin(); it != cpu_fits.end() ; ++it)
        {
            unsigned int snode = std::get<1>(*it);

            HostShareNode &n = get_node(snode);

            unsigned int mem_snode = n.distance[hop];

            if ( mem_fits.find(mem_snode) != mem_fits.end() )
            {
                HostShareNode &mem_n = get_node(snode);

                nr.node_id     = snode;
                nr.mem_node_id = mem_snode;

                n.allocated_cpus += nr.total_cpus;
                mem_n.allocated_memory += nr.memory;

                return true;
            }
        }
    }

    return false;
}

int HostShareNUMA::make_topology(HostShareRequest &sr, bool verbose)
{
    //**************************************************************************
    //**************************************************************************
    if (verbose)
    {
        std::cout << "\nCONFIGURATION FOR THE TEST\n";
        std::cout << "**************************\n";
        to_cout();
    }
    //**************************************************************************
    //**************************************************************************

    unsigned int t_max; //Max threads per core for this topology
    std::set<int> t_valid; //Viable threads per core combinations for all nodes

    // -------------------------------------------------------------------------
    // User preferences will be used if possible if not they fix an upperbound
    // for the topology parameter.
    // -------------------------------------------------------------------------
    int v_t = sr.threads;
    int c_t = sr.cores;
    int s_t = sr.sockets;

    bool dedicated = sr.dedicated;

    // -------------------------------------------------------------------------
    // Build NUMA NODE topology request vector
    // -------------------------------------------------------------------------
    std::vector<NUMANodeRequest> &vm_nodes = sr.nodes;

    //**************************************************************************
    //**************************************************************************
    //**************************************************************************
    //**************************************************************************
    //**************************************************************************
    //**************************************************************************
    //**************************************************************************
    //**************************************************************************
    //**************************************************************************
    //**************************************************************************
    //--------------------------------------------------------------------------
    // Compute threads per core (tc) in this host:
    //   - Prefer as close as possible to HW configuration, power of 2 (*).
    //   - t_max = min(tc_vm, tc_host). Do not exceed host threads/core
    //   - Possible thread number = 1, 2, 4, 8... t_max
    //   - Prefer higher number of threads and closer to user request
    //   - It should be the same for each virtual numa node
    //
    // (*) Typically processores are 2-way or 4-way SMT
    //--------------------------------------------------------------------------
    if ( dedicated )
    {
        t_max = 1;

        t_valid.insert(1);
    }
    else
    {
        t_max = v_t;

        if ( t_max > threads_core || t_max == 0 )
        {
            t_max = threads_core;
        }

        t_max = 1 << (int) floor(log2((double) t_max));

        // Map <threads/core, virtual nodes>. This is only relevant for
        // asymmetric configurations, different TOTAL_CPUS per NUMA_NODE stanza
        //
        // Example, for 2 numa nodes and 1,2,4 threads/per core
        // 1 - 2 <---- valid in all nodes
        // 2 - 2 <---- valid in all nodes
        // 4 - 1
        // We'll use 2 thread/core topology
        std::map<unsigned int, int> tc_node;

        for (auto vn_it = vm_nodes.begin(); vn_it != vm_nodes.end(); ++vn_it)
        {
            for (unsigned int i = t_max; i >= 1 ; i = i / 2 )
            {
                if ( (*vn_it).total_cpus%i != 0 )
                {
                    continue;
                }

                tc_node[i] = tc_node[i] + 1;
            }
        }

        int t_nodes = static_cast<int>(vm_nodes.size());

        for (int i = t_max; i >= 1 ; i = i / 2 )
        {
            if (tc_node.find(i) != tc_node.end() && tc_node[i] == t_nodes)
            {
                t_valid.insert(i);
            }
        }

        // If the user requested an specific threads/core setup check that
        // we can fulfill it in this host for all the VM nodes.
        if ( v_t != 0 )
        {
            if (t_valid.count(v_t) == 0 )
            {
                return -1;
            }

            t_valid.clear();

            t_valid.insert(v_t);
        }
    }
    /*
    std::cout << "Using Thread configurations: ";

    for ( auto it = t_valid.begin() ; it != t_valid.end(); ++it )
    {
        std::cout << *it << " ";
        };

    std::cout << std::endl;
    */
    //--------------------------------------------------------------------------
    // Schedule NUMA_NODES in the host exploring t_valid threads/core confs
    // and using a best-fit heuristic (memory-guided). Valid nodes needs to:
    //   - Have enough free memory
    //   - Have enough free CPUS groups of a given number of threads/core.
    //
    // Example. TOTAL_CPUS = 4, threads/core = 2 ( - = free, X = used )
    //   - (-XXX),(--XX), (X-XX) ---> Not valid 1 group of 2 threads (4 CPUS)
    //   - (----),(--XX), (X---) ---> Valid 4 group of 2 threads (8 CPUS)
    //
    // NOTE: We want to pin CPUS in the same core in the VM also to CPUS in the
    // same core in the host.
    //--------------------------------------------------------------------------
    unsigned int na = 0;

    for (auto tc_it = t_valid.rbegin(); tc_it != t_valid.rend(); ++tc_it, na = 0)
    {
        for(auto it = nodes.begin(); it != nodes.end(); ++it)
        {
            it->second->allocated_cpus   = 0;
            it->second->allocated_memory = 0;
        }

        for (auto vn_it = vm_nodes.begin(); vn_it != vm_nodes.end(); ++vn_it)
        {
            if (schedule_nodes(*vn_it, *tc_it, dedicated) == false)
            {
                break; //Node cannot be allocated with *tc_it threads/core
            }

            na++;
        }

        if (na == vm_nodes.size())
        {
            v_t = (*tc_it);
            break;
        }
    }

    if (na != vm_nodes.size())
    {
        return -1;
    }

    //--------------------------------------------------------------------------
    // Allocation of NUMA_NODES. Get CPU_IDs for each node
    //--------------------------------------------------------------------------
    for (auto vn_it = vm_nodes.begin(); vn_it != vm_nodes.end(); ++vn_it)
    {
        auto it = nodes.find((*vn_it).node_id);

        if ( it == nodes.end() ) //Consistency check
        {
            return -1;
        }

        if ( dedicated )
        {
            it->second->allocate_dedicated_cpus(0, (*vn_it).total_cpus,
                    (*vn_it).cpu_ids);
        }
        else
        {
            it->second->allocate_ht_cpus(0, (*vn_it).total_cpus, v_t,
                    (*vn_it).cpu_ids);
        }

        it = nodes.find((*vn_it).mem_node_id);

        if ( it == nodes.end() ) //Consistency check
        {
            return -1;
        }

        it->second->mem_usage += (*vn_it).memory;
    }

    //--------------------------------------------------------------------------
    // Update VM topology
    //--------------------------------------------------------------------------
    if ( c_t != 0 )
    {
        s_t = sr.vcpu / ( v_t * c_t );
    }
    else if ( s_t != 0 )
    {
        c_t = sr.vcpu / ( v_t * s_t);
    }
    else
    {
        s_t = 1;
        c_t = sr.vcpu / v_t;
    }


    //**************************************************************************
    //**************************************************************************
    //**************************************************************************
    //**************************************************************************
    //**************************************************************************
    //**************************************************************************
    //**************************************************************************
    //**************************************************************************
    //**************************************************************************
    //**************************************************************************

    sr.sockets = s_t;
    sr.cores   = c_t;
    sr.threads = v_t;

    //**************************************************************************
    //**************************************************************************

    //**************************************************************************
    //**************************************************************************
    if (verbose)
    {
        std::cout << "\nSCHEDULING RESULTS\n";
        std::cout << "******************\n";
        to_cout();

        std::cout << "\n\n";

        std::cout << "VM TOPLOGY: " << sr.sockets << ":" << sr.cores << ":"
                  << sr.threads << "\n";

        for (auto vn_it = vm_nodes.begin(); vn_it != vm_nodes.end(); ++vn_it)
        {
            (*vn_it).to_cout();
        }

    }
    //**************************************************************************
    //**************************************************************************
    return 0;
};

//******************************************************************************
//******************************************************************************
//******************************************************************************
//******************************************************************************
// TESTS TESTS TESTS TESTS TESTS TESTS TESTS
//******************************************************************************
//******************************************************************************
//******************************************************************************
//******************************************************************************

void setup_node(int num_nodes, int num_cores, int num_cpus,
        std::map<unsigned int, HostShareNode *> &nodes, std::set<int> used_cpu,
        std::set<int> dedicated_cores, long long total, long long usage)
{
    for ( int i = 0 ; i < num_nodes; ++i )
    {
        std::vector<Core> cores;

        for (int j = 0; j < num_cores ; ++j)
        {
            std::ostringstream oss;

            int core_id = j + (i * num_cores);

            bool dedicated = dedicated_cores.count(core_id) == 1;

            for (int k = 0; k < num_cpus ; ++k )
            {
                if ( k != 0 )
                {
                    oss << ",";
                }

                int cpu_id = core_id + k * (num_cores * num_nodes);

                oss << cpu_id << ":";

                if ( dedicated )
                {
                    if ( k == 0 )
                    {
                        oss << "2";
                    }
                    else
                    {
                        oss << "-1";
                    }
                }
                else
                {
                    if ( used_cpu.count(cpu_id) != 0 )
                    {
                        oss << "2";
                    }
                    else
                    {
                        oss << "-1";
                    }
                }
            }

            if ( dedicated )
            {
                Core c(core_id, oss.str(), 1, true);
                cores.push_back(c);
            }
            else
            {
                Core c(core_id, oss.str(), 1, false);
                cores.push_back(c);
            }
        }

        std::vector<unsigned int> distance;

        distance.push_back(i);

        for (int j = 0 ; j < num_nodes ; ++j)
        {
            if ( j != i )
            {
                distance.push_back(j);
            }
        }

        HostShareNode * n = new HostShareNode(i, num_cpus, cores, total * 1024,
                usage * 1024, distance);

        nodes.insert(std::make_pair(i, n));
    }
};


int empty_host_single_node_ht(bool verbose)
{
    std::cout << __FUNCTION__;

    int num_nodes = 2;
    int num_cores = 4;
    int num_cpus  = 2;

    std::map<unsigned int, HostShareNode *> nodes;

    std::set<int> used_cpu = {};
    std::set<int> dedicated_cores = {};

    setup_node(num_nodes, num_cores, num_cpus, nodes, used_cpu, dedicated_cores,
            8192,0);

    HostShareNUMA host(num_cpus, nodes);

    // {total_cpus, memory, node_id, cpu_ids, mem_node_id}
    NUMANodeRequest vm_node0 = {4, 4096*1024,-1,"",-1};

    std::vector<NUMANodeRequest> vm_nodes = {vm_node0};

    //vcpu, cpu, mem, disk, dedicated, threads, cores, sockets, nodes
    HostShareRequest sr = {4, 4, 4096, 0, false, 0, 0, 0, vm_nodes};

    int rc = host.make_topology(sr, verbose);

    if (rc == -1)
    {
        return -1;
    }

    if (sr.nodes[0].cpu_ids != "0,8,1,9")
    {

        return -1;
    }

    if (sr.nodes[0].node_id != 0 )
    {
        return -1;
    }

    if (sr.threads != 2 || sr.cores != 2 || sr.sockets != 1)
    {
        return -1;
    }

    std::map<unsigned int, HostShareNode *> nodes1;

    num_cpus  = 4;
    setup_node(num_nodes, num_cores, num_cpus, nodes1, used_cpu, dedicated_cores,
            8192, 0);

    HostShareNUMA host1(num_cpus, nodes1);

    NUMANodeRequest vm_node01 = {4,4096*1024,-1,"",-1};
    std::vector<NUMANodeRequest> vm_nodes1 = {vm_node01};

    HostShareRequest sr1 = {4, 4, 4096, 0, false, 0, 0, 0, vm_nodes1};

    rc = host1.make_topology(sr1, verbose);

    if (rc == -1)
    {
        return -1;
    }

    if (sr1.nodes[0].cpu_ids != "0,8,16,24")
    {
        return -1;
    }

    if (sr1.nodes[0].node_id != 0 )
    {
        return -1;
    }

    if (sr1.threads != 4 || sr1.cores != 1 || sr1.sockets != 1)
    {
        return -1;
    }

    return 0;
}


int empty_host_single_node_dedicated(bool verbose)
{
    std::cout << __FUNCTION__;

    int num_nodes = 2;
    int num_cores = 4;
    int num_cpus  = 2;

    std::map<unsigned int, HostShareNode *> nodes;

    std::set<int> used_cpu = {};
    std::set<int> dedicated_cores = {};

    setup_node(num_nodes, num_cores, num_cpus, nodes, used_cpu, dedicated_cores,
            8192, 0);

    HostShareNUMA host(num_cpus, nodes);

    // {total_cpus, memory, node_id, cpu_ids}
    NUMANodeRequest vm_node0 = {4,4096*1024,-1,""};

    std::vector<NUMANodeRequest> vm_nodes = {vm_node0};

    //vcpu, cpu, mem, disk, dedicated, threads, cores, sockets, nodes
    HostShareRequest sr = {4, 4, 4096, 0, true, 0, 0, 0, vm_nodes};

    int rc = host.make_topology(sr, verbose);

    if (rc == -1)
    {
        return -1;
    }

    if (sr.nodes[0].cpu_ids != "0,1,2,3")
    {

        return -1;
    }

    if (sr.nodes[0].node_id != 0 )
    {
        return -1;
    }

    if (sr.threads != 1 || sr.cores != 4 || sr.sockets != 1)
    {
        return -1;
    }

    std::map<unsigned int, HostShareNode *> nodes1;

    num_cpus  = 4;
    setup_node(num_nodes, num_cores, num_cpus, nodes1, used_cpu, dedicated_cores, 
            8192, 0);

    HostShareNUMA host1(num_cpus, nodes1);

    NUMANodeRequest vm_node01 = {4,4096*1024,-1,""};
    std::vector<NUMANodeRequest> vm_nodes1 = {vm_node01};

    HostShareRequest sr1 = {4, 4, 4096, 0, true, 0, 0, 0, vm_nodes1};

    rc = host1.make_topology(sr1, verbose);

    if (rc == -1)
    {
        return -1;
    }

    if (sr1.nodes[0].cpu_ids != "0,1,2,3")
    {
        return -1;
    }

    if (sr1.nodes[0].node_id != 0 )
    {
        return -1;
    }

    if (sr1.threads != 1 || sr1.cores != 4 || sr1.sockets != 1)
    {
        return -1;
    }

    return 0;
}

int ocuppied_host_single_node_ht(bool verbose)
{
    std::cout << __FUNCTION__;

    int num_nodes = 2;
    int num_cores = 4;
    int num_cpus  = 2;

    std::map<unsigned int, HostShareNode *> nodes;

    std::set<int> used_cpu = {0,1,9,5,11,17};
    std::set<int> dedicated_cores = {};

    setup_node(num_nodes, num_cores, num_cpus, nodes, used_cpu, dedicated_cores,
            8192,0);

    HostShareNUMA host(num_cpus, nodes);

    NUMANodeRequest vm_node0 = {4,4096*1024,-1,""};

    std::vector<NUMANodeRequest> vm_nodes = {vm_node0};
    HostShareRequest sr = {4, 4, 4096, 0, false, 0, 0, 0, vm_nodes};

    int rc = host.make_topology(sr, verbose);

    if (rc == -1)
    {
        return -1;
    }

    if (sr.nodes[0].node_id != 1 || sr.nodes[0].cpu_ids != "4,12,6,14")
    {
        return -1;
    }

    if (sr.threads != 2 || sr.cores != 2 || sr.sockets != 1)
    {
        return -1;
    }

    std::map<unsigned int, HostShareNode *> nodes1;

    num_cpus  = 4;
    num_nodes = 4;
    std::set<int> dedicated_cores2 = {2,3};
    setup_node(num_nodes, num_cores, num_cpus, nodes1, used_cpu, dedicated_cores2,
            8192,0);

    HostShareNUMA host1(num_cpus, nodes1);

    rc = host1.make_topology(sr, verbose);

    if (rc == -1)
    {
        return -1;
    }

    if (sr.nodes[0].cpu_ids != "16,32,33,49" || sr.nodes[0].node_id != 0)
    {
        return -1;
    }

    if (sr.threads != 2 || sr.cores != 2 || sr.sockets != 1)
    {
        return -1;
    }

    NUMANodeRequest vm_node2 = {4,4096*1024,-1,""};

    std::vector<NUMANodeRequest> vm_nodes2 = {vm_node2};
    HostShareRequest sr2 = {4, 4, 4096, 0, false, 0, 0, 0, vm_nodes2};

    rc = host1.make_topology(sr2, verbose);

    if (rc == -1)
    {
        return -1;
    }

    //Test also best fit for CPU
    if (sr2.nodes[0].cpu_ids != "8,24,40,56" || sr2.nodes[0].node_id != 2)
    {
        return -1;
    }

    if (sr2.threads != 4 || sr2.cores != 1 || sr2.sockets != 1)
    {
        return -1;
    }

    return 0;
}


int ocuppied_host_single_node_dedicated(bool verbose)
{
    std::cout << __FUNCTION__;

    int num_nodes = 2;
    int num_cores = 4;
    int num_cpus  = 2;

    std::map<unsigned int, HostShareNode *> nodes;

    std::set<int> used_cpu = {0,1,9,11,17};
    std::set<int> dedicated_cores = {};

    setup_node(num_nodes, num_cores, num_cpus, nodes, used_cpu, dedicated_cores,
            8192,0);

    HostShareNUMA host(num_cpus, nodes);

    NUMANodeRequest vm_node0 = {4,4096*1024,-1,""};

    std::vector<NUMANodeRequest> vm_nodes = {vm_node0};
    HostShareRequest sr = {4, 4, 4096, 0, true, 0, 0, 0, vm_nodes};

    int rc = host.make_topology(sr, verbose);

    if (rc == -1)
    {
        return -1;
    }

    if (sr.nodes[0].node_id != 1 || sr.nodes[0].cpu_ids != "4,5,6,7")
    {
        return -1;
    }

    if (sr.threads != 1 || sr.cores != 4 || sr.sockets != 1)
    {
        return -1;
    }

    std::map<unsigned int, HostShareNode *> nodes1;

    num_cpus  = 4;
    num_nodes = 4;
    std::set<int> dedicated_cores2 = {2,3};
    setup_node(num_nodes, num_cores, num_cpus, nodes1, used_cpu, dedicated_cores2
            ,8192,0);

    HostShareNUMA host1(num_cpus, nodes1);

    rc = host1.make_topology(sr, verbose);

    if (rc == -1)
    {
        return -1;
    }

    if (sr.nodes[0].node_id != 1 || sr.nodes[0].cpu_ids != "4,5,6,7")
    {
        return -1;
    }

    if (sr.threads != 1 || sr.cores != 4 || sr.sockets != 1)
    {
        return -1;
    }

    NUMANodeRequest vm_node2 = {4,4096*1024,-1,""};

    std::vector<NUMANodeRequest> vm_nodes2 = {vm_node2};
    HostShareRequest sr2 = {4, 4, 4096, 0, true, 0, 0, 0, vm_nodes2};

    rc = host1.make_topology(sr2, verbose);

    if (rc == -1)
    {
        return -1;
    }

    if (sr2.nodes[0].cpu_ids != "12,13,14,15" || sr2.nodes[0].node_id != 3)
    {
        return -1;
    }

    if (sr2.threads != 1 || sr2.cores != 4 || sr2.sockets != 1)
    {
        return -1;
    }

    return 0;
}

int ocuppied_host_multiple_node_ht1(bool verbose)
{
    std::cout << __FUNCTION__;

    int num_nodes = 4;
    int num_cores = 4;
    int num_cpus  = 2;

    std::map<unsigned int, HostShareNode *> nodes;

    std::set<int> used_cpu = {0,1,3,19,9,11,17,6,4};
    std::set<int> dedicated_cores = {8,13};

    setup_node(num_nodes, num_cores, num_cpus, nodes, used_cpu, dedicated_cores,
            8192,0);

    HostShareNUMA host(num_cpus, nodes);

    NUMANodeRequest vm_node0 = {4,2048*1024,-1,""};
    NUMANodeRequest vm_node1 = {4,2048*1024,-1,""};

    std::vector<NUMANodeRequest> vm_nodes = {vm_node0, vm_node1};
    HostShareRequest sr = {8, 8, 4096, 0, false, 0, 0, 0, vm_nodes};

    int rc = host.make_topology(sr, verbose);

    if (rc == -1)
    {
        return -1;
    }

    if (sr.nodes[0].node_id != 1 || sr.nodes[0].cpu_ids != "5,21,7,23")
    {
        return -1;
    }

    if (sr.nodes[1].node_id != 3 || sr.nodes[1].cpu_ids != "12,28,14,30")
    {
        return -1;
    }

    if (sr.threads != 2 || sr.cores != 4 || sr.sockets != 1)
    {
        return -1;
    }
    return 0;
}

int ocuppied_host_multiple_node_ht2(bool verbose)
{
    std::cout << __FUNCTION__;

    int num_nodes = 4;
    int num_cores = 4;
    int num_cpus  = 2;

    std::map<unsigned int, HostShareNode *> nodes;

    std::set<int> used_cpu = {0,1,3,19,9,11,17,6,4,8,24};
    std::set<int> dedicated_cores = {};

    setup_node(num_nodes, num_cores, num_cpus, nodes, used_cpu, dedicated_cores,
            8192, 0);

    HostShareNUMA host(num_cpus, nodes);

    NUMANodeRequest vm_node0 = {2,2048*1024,-1,""};
    NUMANodeRequest vm_node1 = {2,2048*1024,-1,""};

    std::vector<NUMANodeRequest> vm_nodes = {vm_node0, vm_node1};
    HostShareRequest sr = {4, 4, 4096, 0, true, 0, 0, 0, vm_nodes};

    int rc = host.make_topology(sr, verbose);

    if (rc == -1)
    {
        return -1;
    }

    if (sr.nodes[0].node_id != 1 || sr.nodes[0].cpu_ids != "5,7")
    {
        return -1;
    }

    if (sr.nodes[1].node_id != 3 || sr.nodes[1].cpu_ids != "12,13")
    {
        return -1;
    }

    if (sr.threads != 1 || sr.cores != 4 || sr.sockets != 1)
    {
        return -1;
    }
    return 0;
}

int ocuppied_host_multiple_node_ht3(bool verbose)
{
    std::cout << __FUNCTION__;

    int num_nodes = 4;
    int num_cores = 4;
    int num_cpus  = 4;

    std::map<unsigned int, HostShareNode *> nodes;

    std::set<int> used_cpu = {0,1,3,19,9,11,17,6,4,8,24};
    std::set<int> dedicated_cores = {};

    setup_node(num_nodes, num_cores, num_cpus, nodes, used_cpu, dedicated_cores,
            8192,0);

    HostShareNUMA host(num_cpus, nodes);

    NUMANodeRequest vm_node0 = {4,1024*1024,-1,""};
    NUMANodeRequest vm_node1 = {4,1024*1024,-1,""};
    NUMANodeRequest vm_node2 = {4,1024*1024,-1,""};
    NUMANodeRequest vm_node3 = {4,1024*1024,-1,""};

    std::vector<NUMANodeRequest> vm_nodes = {vm_node0, vm_node1, vm_node2, vm_node3};
    HostShareRequest sr = {16, 16, 4096, 0, false, 0, 0, 0, vm_nodes};

    int rc = host.make_topology(sr, verbose);

    if (rc == -1)
    {
        return -1;
    }

    if (sr.nodes[0].node_id != 0 || sr.nodes[0].cpu_ids != "2,18,34,50")
    {
        return -1;
    }

    if (sr.nodes[2].node_id != 1 || sr.nodes[2].cpu_ids != "5,21,37,53")
    {
        return -1;
    }

    if (sr.nodes[3].node_id != 1 || sr.nodes[3].cpu_ids != "7,23,39,55")
    {
        return -1;
    }

    if (sr.nodes[1].node_id != 2 || sr.nodes[1].cpu_ids != "10,26,42,58")
    {
        return -1;
    }

    if (sr.threads != 4 || sr.cores != 4 || sr.sockets != 1)
    {
        return -1;
    }

    return 0;
}

int ocuppied_host_multiple_node_ht4(bool verbose)
{
    std::cout << __FUNCTION__;

    int num_nodes = 4;
    int num_cores = 4;
    int num_cpus  = 4;

    std::map<unsigned int, HostShareNode *> nodes;

    std::set<int> used_cpu = {0,1,3,19,9,11,17,6,4,8,24,34,10};
    std::set<int> dedicated_cores = {12,14,15};

    setup_node(num_nodes, num_cores, num_cpus, nodes, used_cpu, dedicated_cores,
            8192, 0);

    HostShareNUMA host(num_cpus, nodes);

    NUMANodeRequest vm_node0 = {4,1024*1024,-1,""};
    NUMANodeRequest vm_node1 = {4,1024*1024,-1,""};
    NUMANodeRequest vm_node2 = {4,1024*1024,-1,""};
    NUMANodeRequest vm_node3 = {4,1024*1024,-1,""};

    std::vector<NUMANodeRequest> vm_nodes = {vm_node0, vm_node1, vm_node2, vm_node3};
    HostShareRequest sr = {16, 16, 4096, 0, false, 0, 0, 0, vm_nodes};

    int rc = host.make_topology(sr, verbose);

    if (rc == -1)
    {
        return -1;
    }

    if (sr.nodes[1].node_id != 0 || sr.nodes[1].cpu_ids != "16,32,33,49")
    {
        return -1;
    }

    if (sr.nodes[2].node_id != 0 || sr.nodes[2].cpu_ids != "2,18,35,51")
    {
        return -1;
    }

    if (sr.nodes[3].node_id != 2 || sr.nodes[3].cpu_ids != "40,56,25,41")
    {
        return -1;
    }

    if (sr.nodes[0].node_id != 3 || sr.nodes[0].cpu_ids != "13,29,45,61")
    {
        return -1;
    }

    if (sr.threads != 2 || sr.cores != 8 || sr.sockets != 1)
    {
        return -1;
    }

    return 0;
}

int free_constraints_less_threads(bool verbose)
{
    std::cout << __FUNCTION__;

    int num_nodes = 2;
    int num_cores = 4;
    int num_cpus  = 4;

    std::map<unsigned int, HostShareNode *> nodes;

    std::set<int> used_cpu = {0,1,3,19,9,18,11,17,6,4,29};
    std::set<int> dedicated_cores = {8,13,7};

    setup_node(num_nodes, num_cores, num_cpus, nodes, used_cpu, dedicated_cores,
            8192,0);

    HostShareNUMA host(num_cpus, nodes);

    NUMANodeRequest vm_node0 = {4,2048*1024,-1,""};
    NUMANodeRequest vm_node1 = {4,2048*1024,-1,""};

    std::vector<NUMANodeRequest> vm_nodes = {vm_node0, vm_node1};
    HostShareRequest sr = {8, 8, 4096, 0, false, 0, 0, 0, vm_nodes};

    int rc = host.make_topology(sr, verbose);

    if (rc == -1)
    {
        return -1;
    }

    if (sr.nodes[0].node_id != 0 || sr.nodes[0].cpu_ids != "8,16,2,10")
    {
        return -1;
    }

    if (sr.nodes[1].node_id != 1 || sr.nodes[1].cpu_ids != "12,20,5,13")
    {
        return -1;
    }

    if (sr.threads != 2 || sr.cores != 4 || sr.sockets != 1)
    {
        return -1;
    }
    return 0;
}

int constraints_threads(bool verbose)
{
    std::cout << __FUNCTION__;

    int num_nodes = 2;
    int num_cores = 4;
    int num_cpus  = 4;

    std::map<unsigned int, HostShareNode *> nodes;

    std::set<int> used_cpu = {0,1,3,19,9,11,17,6,4,29};
    std::set<int> dedicated_cores = {8,13};

    setup_node(num_nodes, num_cores, num_cpus, nodes, used_cpu, dedicated_cores,
            8192,0);

    HostShareNUMA host(num_cpus, nodes);

    NUMANodeRequest vm_node0 = {4,2048*1024,-1,""};
    NUMANodeRequest vm_node1 = {4,2048*1024,-1,""};

    std::vector<NUMANodeRequest> vm_nodes = {vm_node0, vm_node1};
    HostShareRequest sr = {8, 8, 4096, 0, false, 2, 0, 0, vm_nodes};

    int rc = host.make_topology(sr, verbose);

    if (rc == -1)
    {
        return -1;
    }

    if (sr.nodes[0].node_id != 0 || sr.nodes[0].cpu_ids != "8,16,2,10")
    {
        return -1;
    }

    if (sr.nodes[1].node_id != 1 || sr.nodes[1].cpu_ids != "12,20,5,13")
    {
        return -1;
    }

    if (sr.threads != 2 || sr.cores != 4 || sr.sockets != 1)
    {
        return -1;
    }
    return 0;
}

int constraints_more_threads(bool verbose)
{
    std::cout << __FUNCTION__;

    int num_nodes = 2;
    int num_cores = 4;
    int num_cpus  = 4;

    std::map<unsigned int, HostShareNode *> nodes;

    std::set<int> used_cpu = {0,1,3,19,9,18,11,17,6,4,29};
    std::set<int> dedicated_cores = {8,13,7};

    setup_node(num_nodes, num_cores, num_cpus, nodes, used_cpu, dedicated_cores,
            8192,0);

    HostShareNUMA host(num_cpus, nodes);

    NUMANodeRequest vm_node0 = {4,2048*1024,-1,""};
    NUMANodeRequest vm_node1 = {4,2048*1024,-1,""};

    std::vector<NUMANodeRequest> vm_nodes = {vm_node0, vm_node1};
    HostShareRequest sr = {8, 8, 4096, 0, false, 0, 0, 0, vm_nodes};

    int rc = host.make_topology(sr, verbose);

    if (rc == -1)
    {
        return -1;
    }

    if (sr.nodes[0].node_id != 0 || sr.nodes[0].cpu_ids != "8,16,2,10")
    {
        return -1;
    }

    if (sr.nodes[1].node_id != 1 || sr.nodes[1].cpu_ids != "12,20,5,13")
    {
        return -1;
    }

    if (sr.threads != 2 || sr.cores != 4 || sr.sockets != 1)
    {
        return -1;
    }
    return 0;
}

int constraints_sockets(bool verbose)
{
    std::cout << __FUNCTION__;

    int num_nodes = 2;
    int num_cores = 4;
    int num_cpus  = 4;

    std::map<unsigned int, HostShareNode *> nodes;

    std::set<int> used_cpu = {0,1,9,5,11,17};
    std::set<int> dedicated_cores = {};

    setup_node(num_nodes, num_cores, num_cpus, nodes, used_cpu, dedicated_cores
            ,8192,0);

    HostShareNUMA host(num_cpus, nodes);

    NUMANodeRequest vm_node0 = {8,4096*1024,-1,""};

    std::vector<NUMANodeRequest> vm_nodes = {vm_node0};
    HostShareRequest sr = {8, 8, 4096, 0, false, 2, 2, 0, vm_nodes};

    int rc = host.make_topology(sr, verbose);

    if (rc == -1)
    {
        return -1;
    }

    if (sr.nodes[0].node_id != 0 || sr.nodes[0].cpu_ids != "8,16,2,10,18,26,3,19")
    {
        return -1;
    }

    if (sr.threads != 2 || sr.cores != 2 || sr.sockets != 2)
    {
        return -1;
    }

    return 0;
}

int no_space(bool verbose)
{
    std::cout << __FUNCTION__;

    int num_nodes = 2;
    int num_cores = 4;
    int num_cpus  = 2;

    std::map<unsigned int, HostShareNode *> nodes;

    std::set<int> used_cpu = {0,1,9,5,11,14,7};
    std::set<int> dedicated_cores = {};

    setup_node(num_nodes, num_cores, num_cpus, nodes, used_cpu, dedicated_cores,
            8192,0);

    HostShareNUMA host(num_cpus, nodes);

    NUMANodeRequest vm_node0 = {4,4096*1024,-1,""};

    std::vector<NUMANodeRequest> vm_nodes = {vm_node0};
    HostShareRequest sr = {4, 4, 4096, 0, false, 2, 2, 0, vm_nodes};

    int rc = host.make_topology(sr, verbose);

    if (rc == -1)
    {
        return 0;
    }

    return -1;
}

int no_space1(bool verbose)
{
    std::cout << __FUNCTION__;

    int num_nodes = 2;
    int num_cores = 4;
    int num_cpus  = 4;

    std::map<unsigned int, HostShareNode *> nodes;

    std::set<int> used_cpu = {0,1,9,14,7,16,24};
    std::set<int> dedicated_cores = {3,4,5,6,7,2};

    setup_node(num_nodes, num_cores, num_cpus, nodes, used_cpu, dedicated_cores,
            8192,0);

    HostShareNUMA host(num_cpus, nodes);

    NUMANodeRequest vm_node0 = {4,4096*1024,-1,""};

    std::vector<NUMANodeRequest> vm_nodes = {vm_node0};
    HostShareRequest sr = {4, 4, 4096, 0, false, 2, 2, 0, vm_nodes};

    int rc = host.make_topology(sr, verbose);

    if (rc == -1)
    {
        return 0;
    }

    return -1;
}

int no_space2(bool verbose)
{
    std::cout << __FUNCTION__;

    int num_nodes = 2;
    int num_cores = 4;
    int num_cpus  = 4;

    std::map<unsigned int, HostShareNode *> nodes;

    std::set<int> used_cpu = {0,1,9,14,7,16,24,20,5};
    std::set<int> dedicated_cores = {3,6,7,2};

    setup_node(num_nodes, num_cores, num_cpus, nodes, used_cpu, dedicated_cores,
            8192,0);

    HostShareNUMA host(num_cpus, nodes);

    NUMANodeRequest vm_node0 = {4,4096*1024,-1,""};

    std::vector<NUMANodeRequest> vm_nodes = {vm_node0};
    HostShareRequest sr = {4, 4, 4096, 0, false, 4, 1, 0, vm_nodes};

    int rc = host.make_topology(sr, verbose);

    if (rc == -1)
    {
        return 0;
    }

    return -1;
}

int no_space3(bool verbose)
{
    std::cout << __FUNCTION__;

    int num_nodes = 2;
    int num_cores = 4;
    int num_cpus  = 4;

    std::map<unsigned int, HostShareNode *> nodes;

    std::set<int> used_cpu = {0,1,3,19,9,18,11,17,29};
    std::set<int> dedicated_cores = {4,6,7};

    setup_node(num_nodes, num_cores, num_cpus, nodes, used_cpu, dedicated_cores,
            8192,0);

    HostShareNUMA host(num_cpus, nodes);

    NUMANodeRequest vm_node0 = {4,2048*1024,-1,""};
    NUMANodeRequest vm_node1 = {4,2048*1024,-1,""};

    std::vector<NUMANodeRequest> vm_nodes = {vm_node0, vm_node1};
    HostShareRequest sr = {8, 8, 4096, 0, false, 2, 0, 0, vm_nodes};

    int rc = host.make_topology(sr, verbose);

    if (rc == -1)
    {
        return 0;
    }

    return -1;
}

int memory_schedule1(bool verbose)
{
    std::cout << __FUNCTION__;

    int num_nodes = 4;
    int num_cores = 4;
    int num_cpus  = 2;

    std::map<unsigned int, HostShareNode *> nodes;

    std::set<int> used_cpu = {0,1,3,19,9,17,6,4};
    std::set<int> dedicated_cores = {8,13};

    setup_node(num_nodes, num_cores, num_cpus, nodes, used_cpu, dedicated_cores,
            8192,0);

    nodes[0]->mem_usage = 7*1024*1024;
    nodes[1]->mem_usage = 7*1024*1024;
    nodes[3]->mem_usage = 2*1024*1024;

    HostShareNUMA host(num_cpus, nodes);

    NUMANodeRequest vm_node0 = {4,2048*1024,-1,""};
    NUMANodeRequest vm_node1 = {4,2048*1024,-1,""};

    std::vector<NUMANodeRequest> vm_nodes = {vm_node0, vm_node1};
    HostShareRequest sr = {8, 8, 4096, 0, false, 0, 0, 0, vm_nodes};

    int rc = host.make_topology(sr, verbose);

    if (rc == -1)
    {
        return -1;
    }

    if (sr.nodes[0].node_id != 2 || sr.nodes[0].cpu_ids != "10,26,11,27"
            || sr.nodes[0].mem_node_id != 2)
    {
        return -1;
    }

    if (sr.nodes[1].node_id != 3 || sr.nodes[1].cpu_ids != "12,28,14,30"
            || sr.nodes[1].mem_node_id != 3)
    {
        return -1;
    }

    if (sr.threads != 2 || sr.cores != 4 || sr.sockets != 1)
    {
        return -1;
    }

    NUMANodeRequest vm_node01 = {4,2048*1024,-1,""};
    NUMANodeRequest vm_node11 = {4,2048*1024,-1,""};

    std::vector<NUMANodeRequest> vm_nodes1 = {vm_node01, vm_node11};
    HostShareRequest sr1 = {8, 8, 4096, 0, false, 0, 0, 0, vm_nodes1};

    rc = host.make_topology(sr1, verbose);

    if (rc != -1)
    {
        return -1;
    }

    return 0;
}

int memory_schedule2(bool verbose)
{
    std::cout << __FUNCTION__;

    int num_nodes = 4;
    int num_cores = 4;
    int num_cpus  = 2;

    std::map<unsigned int, HostShareNode *> nodes;

    std::set<int> used_cpu = {0,1,3,19,9,17,6,4};
    std::set<int> dedicated_cores = {8,13};

    setup_node(num_nodes, num_cores, num_cpus, nodes, used_cpu, dedicated_cores,
            8192,0);

    nodes[0]->mem_usage = 7*1024*1024;
    nodes[1]->mem_usage = 7*1024*1024;
    nodes[2]->mem_usage = 7*1024*1024;
    nodes[3]->mem_usage = 7*1024*1024;

    HostShareNUMA host(num_cpus, nodes);

    NUMANodeRequest vm_node0 = {4,2048*1024,-1,""};
    NUMANodeRequest vm_node1 = {4,2048*1024,-1,""};

    std::vector<NUMANodeRequest> vm_nodes = {vm_node0, vm_node1};
    HostShareRequest sr = {8, 8, 4096, 0, false, 0, 0, 0, vm_nodes};

    int rc = host.make_topology(sr, verbose);

    if (rc != -1)
    {
        return -1;
    }

    return 0;
}

int memory_schedule3(bool verbose)
{
    std::cout << __FUNCTION__;

    int num_nodes = 4;
    int num_cores = 4;
    int num_cpus  = 2;

    std::map<unsigned int, HostShareNode *> nodes;

    std::set<int> used_cpu = {0,3,19,9,6,4,12,28,15};
    std::set<int> dedicated_cores = {8,13,5};

    setup_node(num_nodes, num_cores, num_cpus, nodes, used_cpu, dedicated_cores,
            8192,0);

    nodes[0]->total_mem = 0;
    nodes[0]->free_mem  = 0;
    nodes[0]->used_mem  = 0;
    nodes[0]->mem_usage = 0;
    nodes[0]->distance  = {0,1,2,3};

    nodes[1]->total_mem = 8192*1024;
    nodes[1]->free_mem  = 0;
    nodes[1]->used_mem  = 0;
    nodes[1]->mem_usage = 0;
    nodes[1]->distance  = {1,0,2,3};

    nodes[2]->total_mem = 0;
    nodes[2]->free_mem  = 0;
    nodes[2]->used_mem  = 0;
    nodes[2]->mem_usage = 0;
    nodes[2]->distance  = {2,3,0,1};

    nodes[3]->total_mem = 8192*1024;
    nodes[3]->free_mem  = 0;
    nodes[3]->used_mem  = 0;
    nodes[3]->mem_usage = 0;
    nodes[3]->distance  = {3,2,0,1};

    HostShareNUMA host(num_cpus, nodes);

    NUMANodeRequest vm_node0 = {4,2048*1024,-1,""};
    NUMANodeRequest vm_node1 = {4,2048*1024,-1,""};

    std::vector<NUMANodeRequest> vm_nodes = {vm_node0, vm_node1};
    HostShareRequest sr = {8, 8, 4096, 0, false, 0, 0, 0, vm_nodes};

    int rc = host.make_topology(sr, verbose);

    if (rc == -1)
    {
        return -1;
    }

    if (sr.nodes[0].node_id != 0 || sr.nodes[0].cpu_ids != "1,17,2,18"
            || sr.nodes[0].mem_node_id != 1)
    {
        return -1;
    }

    if (sr.nodes[1].node_id != 2 || sr.nodes[1].cpu_ids != "10,26,11,27"
            || sr.nodes[1].mem_node_id != 3)
    {
        return -1;
    }

    if (sr.threads != 2 || sr.cores != 4 || sr.sockets != 1)
    {
        return -1;
    }

    return 0;
}

int memory_schedule4(bool verbose)
{
    std::cout << __FUNCTION__;

    int num_nodes = 4;
    int num_cores = 4;
    int num_cpus  = 2;

    std::map<unsigned int, HostShareNode *> nodes;

    std::set<int> used_cpu = {0,3,19,9,6,4,12,28,15};
    std::set<int> dedicated_cores = {8,13,5};

    setup_node(num_nodes, num_cores, num_cpus, nodes, used_cpu, dedicated_cores,
            8192,0);

    nodes[0]->total_mem = 0;
    nodes[0]->free_mem  = 0;
    nodes[0]->used_mem  = 0;
    nodes[0]->mem_usage = 0;
    nodes[0]->distance  = {0,1,2,3};

    nodes[1]->total_mem = 8192*1024;
    nodes[1]->free_mem  = 0;
    nodes[1]->used_mem  = 0;
    nodes[1]->mem_usage = 7*1024*1024;
    nodes[1]->distance  = {1,0,2,3};

    nodes[2]->total_mem = 0;
    nodes[2]->free_mem  = 0;
    nodes[2]->used_mem  = 0;
    nodes[2]->mem_usage = 0;
    nodes[2]->distance  = {2,3,0,1};

    nodes[3]->total_mem = 8192*1024;
    nodes[3]->free_mem  = 0;
    nodes[3]->used_mem  = 0;
    nodes[3]->mem_usage = 0;
    nodes[3]->distance  = {3,2,0,1};

    HostShareNUMA host(num_cpus, nodes);

    NUMANodeRequest vm_node0 = {4,2048*1024,-1,""};
    NUMANodeRequest vm_node1 = {4,2048*1024,-1,""};

    std::vector<NUMANodeRequest> vm_nodes = {vm_node0, vm_node1};
    HostShareRequest sr = {8, 8, 4096, 0, false, 0, 0, 0, vm_nodes};

    int rc = host.make_topology(sr, verbose);

    if (rc == -1)
    {
        return -1;
    }

    if (sr.nodes[1].node_id != 0 || sr.nodes[1].cpu_ids != "1,17,2,18"
            || sr.nodes[1].mem_node_id != 3)
    {
        return -1;
    }

    if (sr.nodes[0].node_id != 2 || sr.nodes[0].cpu_ids != "10,26,11,27"
            || sr.nodes[0].mem_node_id != 3)
    {
        return -1;
    }

    if (sr.threads != 2 || sr.cores != 4 || sr.sockets != 1)
    {
        return -1;
    }

    return 0;
}
void do_test(int (*test_func)(bool), bool verbose)
{
    int rc = (*test_func)(verbose);

    if (rc == 0)
    {
        std::cout << ".... success" << std::endl;
    }
    else
    {
        std::cout << ".... failure" << std::endl;
    }
}

int main()
{

    do_test(empty_host_single_node_ht, false);
    do_test(empty_host_single_node_dedicated, false);
    do_test(ocuppied_host_single_node_ht, false);
    do_test(ocuppied_host_single_node_dedicated, false);
    do_test(ocuppied_host_multiple_node_ht1, false);
    do_test(ocuppied_host_multiple_node_ht2, false);
    do_test(ocuppied_host_multiple_node_ht3, false);
    do_test(ocuppied_host_multiple_node_ht4, false);
    do_test(free_constraints_less_threads, false);
    do_test(constraints_threads, false);
    do_test(constraints_more_threads, false);
    do_test(constraints_sockets, false);
    do_test(no_space, false);
    do_test(no_space1, false);
    do_test(no_space2, false);
    do_test(no_space3, false);
    do_test(memory_schedule1, false);
    do_test(memory_schedule2, false);
    do_test(memory_schedule3, false);
    do_test(memory_schedule4, false);

    return 0;
};
