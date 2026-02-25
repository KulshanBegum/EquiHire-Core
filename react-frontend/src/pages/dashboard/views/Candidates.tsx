import { useState, useEffect } from 'react';
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Lock, Unlock, Clock, FileText, ChevronRight, XCircle, Settings2, Loader2 } from "lucide-react";

// Organization ID from Auth/Context normally. Hardcoding for demo purposes
const ORGANIZATION_ID = "04b66df8-12cd-4384-8848-3a99252a1aa0";

export default function CandidateManager() {
    const [statusFilter, setStatusFilter] = useState("all");
    const [activityFilter, setActivityFilter] = useState("all"); // all, seen, unseen
    const [candidates, setCandidates] = useState<any[]>([]);
    const [selectedCandidate, setSelectedCandidate] = useState<any>(null);
    const [isLoading, setIsLoading] = useState(true);
    const [threshold, setThreshold] = useState<number>(70);
    const [isProcessing, setIsProcessing] = useState(false);

    useEffect(() => {
        fetchCandidates();
    }, []);

    const fetchCandidates = async () => {
        setIsLoading(true);
        try {
            const res = await fetch(`http://localhost:9090/api/organizations/${ORGANIZATION_ID}/candidates`);
            if (res.ok) {
                const data = await res.json();
                setCandidates(data);
            }
        } catch (error) {
            console.error("Failed to fetch candidates:", error);
        } finally {
            setIsLoading(false);
        }
    };

    const filteredCandidates = candidates.filter(c => {
        const matchesStatus = statusFilter === "all" || c.status === statusFilter;
        const matchesActivity = activityFilter === "all" || (activityFilter === "seen" ? c.seen : !c.seen);
        return matchesStatus && matchesActivity;
    });

    const markAsSeen = (candidateId: string) => {
        setCandidates(candidates.map(c => c.candidateId === candidateId ? { ...c, seen: true } : c));
    };

    const handleViewDetails = (candidate: any) => {
        markAsSeen(candidate.candidateId);
        setSelectedCandidate(candidate);
    };

    const handleApplyDecision = async (candidateId: string) => {
        setIsProcessing(true);
        try {
            const res = await fetch(`http://localhost:9090/api/candidates/${candidateId}/decide`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ threshold })
            });
            if (res.ok) {
                // Refresh list
                fetchCandidates();
                setSelectedCandidate(null);
            }
        } catch (error) {
            console.error("Decision failed:", error);
        } finally {
            setIsProcessing(false);
        }
    };

    const getStatusColor = (status: string) => {
        switch (status) {
            case 'accepted': return 'text-green-600 bg-green-50 border-green-200';
            case 'rejected': return 'text-red-600 bg-red-50 border-red-200';
            case 'scheduled': return 'text-blue-600 bg-blue-50 border-blue-200';
            default: return 'text-amber-600 bg-amber-50 border-amber-200';
        }
    };

    return (
        <div className="flex h-[calc(100vh-8rem)] gap-6">
            {/* List Side */}
            <div className={`flex-1 flex flex-col space-y-4 transition-all ${selectedCandidate ? 'w-1/2' : 'w-full'}`}>
                <div className="flex flex-col md:flex-row justify-between gap-4">
                    <div>
                        <h2 className="text-2xl font-bold text-gray-900">Candidates</h2>
                        <p className="text-gray-500">Manage hiring pipeline.</p>
                    </div>
                    <div className="flex space-x-2">
                        <div className="flex space-x-1 bg-gray-100 p-1 rounded-md">
                            <button onClick={() => setActivityFilter('all')} className={`px-3 py-1 text-xs rounded ${activityFilter === 'all' ? 'bg-white shadow' : 'text-gray-500'}`}>All</button>
                            <button onClick={() => setActivityFilter('unseen')} className={`px-3 py-1 text-xs rounded ${activityFilter === 'unseen' ? 'bg-white shadow font-bold text-blue-600' : 'text-gray-500'}`}>Unseen</button>
                        </div>
                        <select
                            className="bg-white border border-gray-200 text-gray-700 text-sm rounded-md focus:ring-[#FF7300] focus:border-[#FF7300] block p-2"
                            value={statusFilter}
                            onChange={(e) => setStatusFilter(e.target.value)}
                        >
                            <option value="all">All Status</option>
                            <option value="pending">Pending</option>
                            <option value="accepted">Accepted</option>
                            <option value="rejected">Rejected</option>
                            <option value="scheduled">Scheduled</option>
                        </select>
                        <div className="flex items-center space-x-2 bg-white border border-gray-200 rounded-md px-3">
                            <Settings2 className="w-4 h-4 text-gray-400" />
                            <span className="text-sm text-gray-500 font-medium">Auto-Pass Threshold:</span>
                            <input
                                type="number"
                                min="0" max="100"
                                value={threshold}
                                onChange={e => setThreshold(Number(e.target.value))}
                                className="w-14 text-sm font-bold text-[#FF7300] focus:outline-none bg-transparent"
                            />
                            <span className="text-sm font-bold text-gray-400">%</span>
                        </div>
                    </div>
                </div>

                <Card className="flex-1 overflow-hidden border-gray-200 shadow-sm flex flex-col">
                    <div className="overflow-auto flex-1">
                        <table className="w-full text-sm text-left">
                            <thead className="bg-gray-50 text-gray-500 font-medium border-b border-gray-100 sticky top-0">
                                <tr>
                                    <th className="px-6 py-3">Candidate</th>
                                    <th className="px-6 py-3">Role</th>
                                    <th className="px-6 py-3">Score</th>
                                    <th className="px-6 py-3">Status</th>
                                    <th className="px-6 py-3"></th>
                                </tr>
                            </thead>
                            <tbody className="divide-y divide-gray-100">
                                {isLoading ? (
                                    <tr>
                                        <td colSpan={5} className="px-6 py-10 text-center text-gray-500">
                                            <Loader2 className="w-6 h-6 animate-spin mx-auto mb-2 text-[#FF7300]" />
                                            Loading candidates...
                                        </td>
                                    </tr>
                                ) : filteredCandidates.map((c) => (
                                    <tr
                                        key={c.candidateId}
                                        className={`hover:bg-gray-50/80 transition-colors cursor-pointer ${selectedCandidate?.candidateId === c.candidateId ? 'bg-blue-50/50' : ''}`}
                                        onClick={() => handleViewDetails(c)}
                                    >
                                        <td className="px-6 py-4">
                                            <div className="flex items-center">
                                                <div className={`w-8 h-8 rounded-full flex items-center justify-center mr-3 ${c.status === 'accepted' ? 'bg-green-100 text-green-700' : 'bg-gray-200 text-gray-600'}`}>
                                                    {c.status === 'accepted' ? <Unlock className="w-4 h-4" /> : <Lock className="w-4 h-4" />}
                                                </div>
                                                <div className="flex flex-col">
                                                    <span className={`${c.status === 'accepted' ? 'text-gray-900' : 'text-gray-500 font-mono tracking-wider'} ${!c.seen ? 'font-bold text-gray-900' : ''}`}>
                                                        {c.candidateName}
                                                    </span>
                                                    {!c.seen && <span className="text-[10px] text-blue-600 font-bold uppercase tracking-wide">New Update</span>}
                                                </div>
                                            </div>
                                        </td>
                                        <td className="px-6 py-4 text-gray-600">{c.jobTitle}</td>
                                        <td className="px-6 py-4">
                                            {c.score > 0 ? (
                                                <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-bold ${c.score >= 80 ? 'bg-green-100 text-green-800' :
                                                    c.score >= 60 ? 'bg-yellow-100 text-yellow-800' :
                                                        'bg-red-100 text-red-800'
                                                    }`}>
                                                    {c.score}/100
                                                </span>
                                            ) : (
                                                <span className="text-gray-400 text-xs text-center">—</span>
                                            )}

                                        </td>
                                        <td className="px-6 py-4">
                                            <span className={`inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium border ${getStatusColor(c.status)}`}>
                                                {c.status.charAt(0).toUpperCase() + c.status.slice(1)}
                                            </span>
                                        </td>
                                        <td className="px-6 py-4 text-right text-gray-400">
                                            <ChevronRight className="w-4 h-4" />
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                </Card>
            </div>

            {/* Detail Sheet/Panel */}
            {selectedCandidate && (
                <div className="w-[400px] flex flex-col space-y-4 animate-in slide-in-from-right-10 duration-300">
                    <div className="flex justify-between items-center h-8"> {/* Spacer to align with title */}
                        <h3 className="font-bold text-gray-900">Candidate Details</h3>
                        <button onClick={() => setSelectedCandidate(null)} className="text-gray-400 hover:text-gray-900">
                            <XCircle className="w-5 h-5" />
                        </button>
                    </div>

                    <Card className="flex-1 shadow-lg border-gray-200 overflow-auto">
                        <CardHeader className="bg-gray-50 border-b border-gray-100 pb-6">
                            <div className="flex flex-col items-center">
                                <div className={`w-20 h-20 rounded-full flex items-center justify-center mb-4 shadow-sm ${selectedCandidate.status === 'accepted' ? 'bg-white' : 'bg-gray-200'}`}>
                                    {selectedCandidate.status === 'accepted' ? (
                                        <img src={`https://api.dicebear.com/7.x/avataaars/svg?seed=${selectedCandidate.name}`} alt="Avatar" className="w-full h-full rounded-full" />
                                    ) : (
                                        <Lock className="w-8 h-8 text-gray-400" />
                                    )}
                                </div>
                                <CardTitle className="text-center">
                                    {selectedCandidate.candidateName}
                                </CardTitle>
                                <CardDescription className="text-center font-mono text-xs mt-1 text-gray-500">
                                    ID: {selectedCandidate.candidateId.split('-')[0]} • {selectedCandidate.jobTitle}
                                </CardDescription>
                            </div>
                        </CardHeader>
                        <CardContent className="pt-6 space-y-6">
                            {/* Overall Score Component */}
                            <div className="p-4 bg-gray-50 rounded-lg border border-gray-100">
                                <div className="flex justify-between items-center mb-2">
                                    <span className="text-xs font-semibold uppercase text-gray-500">Overall AI Match</span>
                                    {selectedCandidate.score > 0 && <span className="font-bold text-lg text-gray-900">{selectedCandidate.score}%</span>}
                                </div>
                                <div className="w-full bg-gray-200 rounded-full h-2 mb-4">
                                    <div
                                        className={`h-2 rounded-full transition-all duration-500 ${selectedCandidate.score >= threshold ? 'bg-[#FF7300]' : 'bg-red-400'}`}
                                        style={{ width: `${selectedCandidate.score}%` }}
                                    ></div>
                                </div>

                                {selectedCandidate.score > 0 ? (
                                    <div className="space-y-2 mt-2 pt-3 border-t border-gray-200 border-dashed">
                                        <div className="flex justify-between text-xs">
                                            <span className="text-gray-500">CV / Resume</span>
                                            <span className="font-medium text-gray-700">{selectedCandidate.cvScore}%</span>
                                        </div>
                                        <div className="flex justify-between text-xs">
                                            <span className="text-gray-500">Required Skills</span>
                                            <span className="font-medium text-gray-700">{selectedCandidate.skillsScore}%</span>
                                        </div>
                                        <div className="flex justify-between text-xs">
                                            <span className="text-gray-500">Technical Interview</span>
                                            <span className="font-medium text-gray-700">{selectedCandidate.interviewScore}%</span>
                                        </div>
                                    </div>
                                ) : (
                                    <p className="text-xs text-gray-400 italic">Interview pending or not graded.</p>
                                )}
                            </div>

                            {/* Lifecycle Stage */}
                            <div>
                                <h4 className="text-sm font-bold text-gray-900 mb-4 flex items-center">
                                    <Clock className="w-4 h-4 mr-2 text-gray-500" /> Timeline
                                </h4>
                                <div className="relative pl-4 border-l-2 border-gray-100 space-y-6">
                                    <div className="relative">
                                        <div className="absolute -left-[21px] top-1 w-3 h-3 bg-green-500 rounded-full border-2 border-white ring-2 ring-gray-50"></div>
                                        <p className="text-sm font-medium text-gray-900">Application Received</p>
                                        <p className="text-xs text-gray-500">{new Date(selectedCandidate.appliedDate).toLocaleDateString()}</p>
                                    </div>
                                    <div className="relative">
                                        <div className={`absolute -left-[21px] top-1 w-3 h-3 rounded-full border-2 border-white ring-2 ring-gray-50 ${selectedCandidate.score > 0 ? 'bg-green-500' : 'bg-gray-300'}`}></div>
                                        <p className="text-sm font-medium text-gray-900">Interview Session</p>
                                        <p className="text-xs text-gray-500">{selectedCandidate.score > 0 ? "Completed" : "Scheduled"}</p>
                                    </div>
                                    <div className="relative">
                                        <div className={`absolute -left-[21px] top-1 w-3 h-3 rounded-full border-2 border-white ring-2 ring-gray-50 ${selectedCandidate.status !== 'pending' && selectedCandidate.status !== 'scheduled' ? 'bg-green-500' : 'bg-gray-300'}`}></div>
                                        <p className="text-sm font-medium text-gray-900">Final Decision</p>
                                        <p className="text-xs text-gray-500">
                                            {selectedCandidate.status === 'pending' ? 'Pending Review' :
                                                selectedCandidate.status === 'accepted' ? 'Accepted' :
                                                    selectedCandidate.status === 'rejected' ? 'Rejected' : 'Pending'}
                                        </p>
                                    </div>
                                </div>
                            </div>

                            <div className="pt-4 border-t border-gray-100 flex flex-col gap-2">
                                {selectedCandidate.status === 'pending' && selectedCandidate.score > 0 && (
                                    <Button
                                        className={`w-full ${selectedCandidate.score >= threshold ? 'bg-green-600 hover:bg-green-700 text-white' : 'bg-red-600 hover:bg-red-700 text-white'}`}
                                        onClick={() => handleApplyDecision(selectedCandidate.candidateId)}
                                        disabled={isProcessing}
                                    >
                                        {isProcessing ? <Loader2 className="w-4 h-4 animate-spin mr-2" /> : <Lock className="w-4 h-4 mr-2" />}
                                        {selectedCandidate.score >= threshold ? 'Accept & Reveal Name' : 'Reject & Anonymize'} (Threshold {threshold}%)
                                    </Button>
                                )}
                                <Button className="w-full" variant="outline">
                                    <FileText className="w-4 h-4 mr-2" /> View Full Transcript
                                </Button>
                            </div>
                        </CardContent>
                    </Card>
                </div>
            )}
        </div>
    );
}
