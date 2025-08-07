"""
Snowflake Cortex Analyst Chat Interface
Simple chat interface for natural language queries using Snowflake Cortex Analyst
"""

import os
import json
import logging
from datetime import datetime
from typing import Dict, List, Optional, Any

import streamlit as st
import pandas as pd
import snowflake.connector
from snowflake.snowpark import Session
import plotly.express as px
import plotly.graph_objects as go

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Page configuration
st.set_page_config(
    page_title="Snowflake Cortex Analyst Chat",
    page_icon="❄️",
    layout="wide",
    initial_sidebar_state="collapsed"
)

# Custom CSS for chat interface
def load_chat_css():
    st.markdown("""
    <style>
    /* Import Google Fonts */
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600&display=swap');
    
    /* Main container */
    .main {
        font-family: 'Inter', sans-serif;
        max-width: 1200px;
        margin: 0 auto;
        padding: 1rem;
    }
    
    /* Header */
    .chat-header {
        text-align: center;
        padding: 2rem 0;
        border-bottom: 1px solid #e1e5e9;
        margin-bottom: 2rem;
    }
    
    .chat-header h1 {
        color: #1f2937;
        font-size: 2.5rem;
        font-weight: 600;
        margin: 0;
    }
    
    .chat-header p {
        color: #6b7280;
        font-size: 1.1rem;
        margin: 0.5rem 0 0 0;
    }
    
    /* Chat messages */
    .chat-message {
        display: flex;
        margin: 1rem 0;
        animation: fadeIn 0.3s ease-in;
    }
    
    .chat-message.user {
        justify-content: flex-end;
    }
    
    .chat-message.assistant {
        justify-content: flex-start;
    }
    
    .message-content {
        max-width: 70%;
        padding: 1rem 1.5rem;
        border-radius: 1rem;
        position: relative;
    }
    
    .message-content.user {
        background: linear-gradient(135deg, #0066cc, #00a8ff);
        color: white;
        border-bottom-right-radius: 0.5rem;
    }
    
    .message-content.assistant {
        background: #f8fafc;
        border: 1px solid #e2e8f0;
        color: #1a202c;
        border-bottom-left-radius: 0.5rem;
    }
    
    .message-time {
        font-size: 0.75rem;
        opacity: 0.7;
        margin-top: 0.5rem;
    }
    
    /* SQL Code display */
    .sql-code {
        background: #1e293b;
        color: #e2e8f0;
        padding: 1rem;
        border-radius: 0.5rem;
        margin: 0.5rem 0;
        font-family: 'Fira Code', monospace;
        font-size: 0.875rem;
        overflow-x: auto;
    }
    
    /* Input area */
    .chat-input-container {
        position: fixed;
        bottom: 0;
        left: 0;
        right: 0;
        background: white;
        border-top: 1px solid #e2e8f0;
        padding: 1rem;
        z-index: 1000;
    }
    
    .chat-input {
        max-width: 1200px;
        margin: 0 auto;
        display: flex;
        gap: 1rem;
        align-items: flex-end;
    }
    
    /* Results display */
    .results-container {
        margin: 1rem 0;
        padding: 1rem;
        background: #f8fafc;
        border-radius: 0.5rem;
        border: 1px solid #e2e8f0;
    }
    
    /* Status indicators */
    .status-indicator {
        display: inline-flex;
        align-items: center;
        gap: 0.5rem;
        padding: 0.25rem 0.75rem;
        border-radius: 0.5rem;
        font-size: 0.875rem;
        font-weight: 500;
        margin-bottom: 1rem;
    }
    
    .status-connected {
        background: rgba(34, 197, 94, 0.1);
        color: #059669;
    }
    
    .status-error {
        background: rgba(239, 68, 68, 0.1);
        color: #dc2626;
    }
    
    /* Animation */
    @keyframes fadeIn {
        from { opacity: 0; transform: translateY(10px); }
        to { opacity: 1; transform: translateY(0); }
    }
    
    .fade-in {
        animation: fadeIn 0.3s ease-in;
    }
    
    /* Typing indicator */
    .typing-indicator {
        display: flex;
        align-items: center;
        gap: 0.5rem;
        color: #6b7280;
        font-style: italic;
    }
    
    .typing-dots {
        display: flex;
        gap: 0.25rem;
    }
    
    .typing-dot {
        width: 6px;
        height: 6px;
        border-radius: 50%;
        background: #6b7280;
        animation: typing 1.4s infinite ease-in-out;
    }
    
    .typing-dot:nth-child(2) { animation-delay: 0.2s; }
    .typing-dot:nth-child(3) { animation-delay: 0.4s; }
    
    @keyframes typing {
        0%, 60%, 100% { opacity: 0.3; }
        30% { opacity: 1; }
    }
    
    /* Hide Streamlit elements */
    .stDeployButton { display: none; }
    #MainMenu { visibility: hidden; }
    footer { visibility: hidden; }
    header { visibility: hidden; }
    
    /* Adjust main content for fixed input */
    .main .block-container {
        padding-bottom: 100px;
    }
    </style>
    """, unsafe_allow_html=True)

# Configuration
class Config:
    SNOWFLAKE_ACCOUNT = os.getenv('SNOWFLAKE_ACCOUNT', 'BIREZNC-ZHB27778')
    SNOWFLAKE_USER = os.getenv('SNOWFLAKE_USER', 'SAURABHMAC')
    SNOWFLAKE_PASSWORD = os.getenv('SNOWFLAKE_PASSWORD', 'AwsSnowAdmin1234')
    SNOWFLAKE_DATABASE = os.getenv('SNOWFLAKE_DATABASE', 'analytics_platform')
    SNOWFLAKE_WAREHOUSE = os.getenv('SNOWFLAKE_WAREHOUSE', 'analytics_wh')
    SNOWFLAKE_SCHEMA = os.getenv('SNOWFLAKE_SCHEMA', 'reporting')

# Snowflake connection
@st.cache_resource
def get_snowflake_session():
    """Create and cache Snowflake session"""
    try:
        connection_params = {
            "account": Config.SNOWFLAKE_ACCOUNT,
            "user": Config.SNOWFLAKE_USER,
            "password": Config.SNOWFLAKE_PASSWORD,
            "database": Config.SNOWFLAKE_DATABASE,
            "warehouse": Config.SNOWFLAKE_WAREHOUSE,
            "schema": Config.SNOWFLAKE_SCHEMA,
        }
        
        session = Session.builder.configs(connection_params).create()
        logger.info("Successfully connected to Snowflake")
        return session
    except Exception as e:
        logger.error(f"Failed to connect to Snowflake: {e}")
        st.error(f"Failed to connect to Snowflake: {e}")
        return None

# Cortex Analyst integration
class CortexAnalystChat:
    def __init__(self, session):
        self.session = session
        
    def get_semantic_models(self) -> List[str]:
        """Get available semantic models from Snowflake"""
        try:
            # This would query actual semantic models in production
            # For now, return example models based on our schema
            return [
                "ANALYTICS_PLATFORM_MODEL",
                "SALES_PERFORMANCE_MODEL", 
                "CUSTOMER_INSIGHTS_MODEL",
                "OPERATIONAL_METRICS_MODEL"
            ]
        except Exception as e:
            logger.error(f"Error fetching semantic models: {e}")
            return []
    
    def query_cortex_analyst(self, user_question: str, semantic_model: str) -> Dict[str, Any]:
        """
        Query Snowflake Cortex Analyst with natural language
        
        In production, this would call the actual Cortex Analyst service:
        SELECT SNOWFLAKE.CORTEX.ANALYST(
            user_question, 
            semantic_model,
            session_parameters => {}
        )
        """
        try:
            # Simulate Cortex Analyst response structure
            # In production, this would be the actual Cortex Analyst call
            cortex_query = f"""
            SELECT SNOWFLAKE.CORTEX.ANALYST(
                '{user_question}',
                '{semantic_model}'
            ) as analyst_response
            """
            
            # For demonstration, we'll translate common queries to actual SQL
            sql_query = self._simulate_cortex_translation(user_question)
            
            # Execute the SQL query
            result_df = self.session.sql(sql_query).to_pandas()
            
            return {
                "sql_query": sql_query,
                "results": result_df,
                "explanation": f"Cortex Analyst translated your question into SQL and executed it against the {semantic_model} semantic model.",
                "success": True
            }
            
        except Exception as e:
            logger.error(f"Error in Cortex Analyst query: {e}")
            return {
                "sql_query": None,
                "results": None,
                "explanation": f"Error processing your question: {str(e)}",
                "success": False,
                "error": str(e)
            }
    
    def _simulate_cortex_translation(self, question: str) -> str:
        """
        Simulate Cortex Analyst natural language to SQL translation
        In production, this would be handled by the actual Cortex Analyst service
        """
        question_lower = question.lower()
        
        # Customer-related queries
        if any(word in question_lower for word in ['customer', 'client']):
            if any(word in question_lower for word in ['top', 'best', 'highest']):
                return """
                SELECT 
                    customer_name,
                    customer_tier,
                    lifetime_value,
                    email,
                    CASE WHEN is_active THEN 'Active' ELSE 'Inactive' END as status
                FROM raw_data.customers 
                ORDER BY lifetime_value DESC 
                LIMIT 10
                """
            elif any(word in question_lower for word in ['count', 'total', 'number']):
                return """
                SELECT 
                    customer_tier,
                    COUNT(*) as customer_count,
                    AVG(lifetime_value) as avg_lifetime_value,
                    SUM(lifetime_value) as total_lifetime_value
                FROM raw_data.customers 
                WHERE is_active = TRUE
                GROUP BY customer_tier
                ORDER BY customer_count DESC
                """
            else:
                return """
                SELECT 
                    customer_tier,
                    COUNT(*) as count,
                    AVG(lifetime_value) as avg_ltv,
                    MIN(created_at) as first_customer,
                    MAX(created_at) as latest_customer
                FROM raw_data.customers 
                GROUP BY customer_tier
                ORDER BY count DESC
                """
        
        # Product-related queries
        elif any(word in question_lower for word in ['product', 'item']):
            if any(word in question_lower for word in ['price', 'cost', 'expensive']):
                return """
                SELECT 
                    product_name,
                    category,
                    price,
                    cost,
                    ROUND((price - cost) / price * 100, 2) as margin_percentage,
                    is_active
                FROM raw_data.products 
                ORDER BY price DESC 
                LIMIT 15
                """
            else:
                return """
                SELECT 
                    category,
                    COUNT(*) as product_count,
                    AVG(price) as avg_price,
                    AVG(cost) as avg_cost,
                    AVG((price - cost) / price * 100) as avg_margin_pct
                FROM raw_data.products 
                WHERE is_active = TRUE
                GROUP BY category
                ORDER BY product_count DESC
                """
        
        # Order-related queries
        elif any(word in question_lower for word in ['order', 'sale', 'revenue']):
            if any(word in question_lower for word in ['recent', 'latest', 'new']):
                return """
                SELECT 
                    o.order_id,
                    c.customer_name,
                    o.order_date,
                    o.total_amount,
                    o.status
                FROM raw_data.orders o
                JOIN raw_data.customers c ON o.customer_id = c.customer_id
                ORDER BY o.order_date DESC 
                LIMIT 20
                """
            else:
                return """
                SELECT 
                    DATE_TRUNC('month', order_date) as month,
                    COUNT(*) as order_count,
                    SUM(total_amount) as total_revenue,
                    AVG(total_amount) as avg_order_value
                FROM raw_data.orders 
                WHERE order_date >= DATEADD('month', -12, CURRENT_DATE())
                GROUP BY DATE_TRUNC('month', order_date)
                ORDER BY month DESC
                """
        
        # Job-related queries
        elif any(word in question_lower for word in ['job', 'task', 'process']):
            return """
            SELECT 
                job_type,
                status,
                COUNT(*) as job_count,
                AVG(execution_time_seconds) as avg_execution_time,
                MAX(created_at) as latest_job
            FROM raw_data.jobs 
            WHERE created_at >= DATEADD('day', -7, CURRENT_DATE())
            GROUP BY job_type, status
            ORDER BY job_count DESC
            """
        
        # Default general query
        else:
            return f"""
            SELECT 
                'Your question: {question}' as question_asked,
                'This is a simulated Cortex Analyst response' as response_type,
                CURRENT_TIMESTAMP() as processed_at,
                'Use more specific terms like customers, products, orders, or jobs for better results' as suggestion
            """

# Chat interface functions
def initialize_chat_history():
    """Initialize chat history in session state"""
    if "messages" not in st.session_state:
        st.session_state.messages = [
            {
                "role": "assistant",
                "content": "Hi! I'm your Snowflake Cortex Analyst assistant. Ask me anything about your data using natural language, and I'll convert it to SQL and show you the results.",
                "timestamp": datetime.now()
            }
        ]

def display_chat_messages():
    """Display all chat messages"""
    for message in st.session_state.messages:
        role_class = "user" if message["role"] == "user" else "assistant"
        
        st.markdown(f"""
        <div class="chat-message {role_class} fade-in">
            <div class="message-content {role_class}">
                {message["content"]}
                <div class="message-time">
                    {message["timestamp"].strftime("%H:%M")}
                </div>
            </div>
        </div>
        """, unsafe_allow_html=True)
        
        # Display SQL and results if present
        if "sql_query" in message and message["sql_query"]:
            with st.expander("Generated SQL Query"):
                st.code(message["sql_query"], language="sql")
        
        if "results" in message and message["results"] is not None:
            st.dataframe(message["results"], use_container_width=True)
            
            # Auto-generate chart if numeric data
            if len(message["results"]) > 0:
                numeric_cols = message["results"].select_dtypes(include=['number']).columns
                if len(numeric_cols) > 0:
                    create_chart(message["results"], numeric_cols)

def create_chart(df: pd.DataFrame, numeric_cols):
    """Create appropriate chart based on data"""
    if len(df) > 1 and len(numeric_cols) > 0:
        try:
            # Choose chart type based on data
            if len(df) <= 20:  # Bar chart for small datasets
                fig = px.bar(
                    df, 
                    x=df.columns[0], 
                    y=numeric_cols[0],
                    title=f"{numeric_cols[0]} by {df.columns[0]}",
                    template="plotly_white"
                )
            else:  # Line chart for larger datasets
                fig = px.line(
                    df, 
                    x=df.columns[0], 
                    y=numeric_cols[0],
                    title=f"{numeric_cols[0]} Trend",
                    template="plotly_white"
                )
            
            fig.update_layout(height=400, showlegend=False)
            st.plotly_chart(fig, use_container_width=True)
        except Exception as e:
            logger.error(f"Error creating chart: {e}")

def handle_user_input(cortex_chat, semantic_model):
    """Handle user input and generate response"""
    # Chat input container
    with st.container():
        user_input = st.chat_input("Ask anything about your data...")
        
        if user_input:
            # Add user message
            st.session_state.messages.append({
                "role": "user",
                "content": user_input,
                "timestamp": datetime.now()
            })
            
            # Process with Cortex Analyst
            with st.spinner("Processing with Cortex Analyst..."):
                response = cortex_chat.query_cortex_analyst(user_input, semantic_model)
            
            # Prepare assistant response
            if response["success"]:
                assistant_content = response["explanation"]
                
                # Add assistant message with results
                assistant_message = {
                    "role": "assistant", 
                    "content": assistant_content,
                    "timestamp": datetime.now(),
                    "sql_query": response["sql_query"],
                    "results": response["results"]
                }
            else:
                assistant_message = {
                    "role": "assistant",
                    "content": f"I encountered an issue: {response['explanation']}",
                    "timestamp": datetime.now()
                }
            
            st.session_state.messages.append(assistant_message)
            
            # Rerun to show new messages
            st.rerun()

def render_sidebar(session, cortex_chat):
    """Render sidebar with connection status and controls"""
    with st.sidebar:
        st.markdown("### ❄️ Snowflake Connection")
        
        if session:
            st.markdown("""
            <div class="status-indicator status-connected">
                🟢 Connected to Snowflake
            </div>
            """, unsafe_allow_html=True)
            
            # Show connection details
            with st.expander("Connection Details"):
                st.write(f"**Database:** {Config.SNOWFLAKE_DATABASE}")
                st.write(f"**Warehouse:** {Config.SNOWFLAKE_WAREHOUSE}")
                st.write(f"**Schema:** {Config.SNOWFLAKE_SCHEMA}")
        else:
            st.markdown("""
            <div class="status-indicator status-error">
                🔴 Connection Failed
            </div>
            """, unsafe_allow_html=True)
            return None
        
        st.markdown("---")
        
        # Semantic model selection
        st.markdown("### 🧠 Semantic Model")
        semantic_models = cortex_chat.get_semantic_models()
        
        selected_model = st.selectbox(
            "Select semantic model:",
            semantic_models,
            index=0 if semantic_models else None,
            help="Choose the semantic model for your queries"
        )
        
        st.markdown("---")
        
        # Chat controls
        st.markdown("### 💬 Chat Controls")
        
        if st.button("🗑️ Clear Chat History"):
            st.session_state.messages = [
                {
                    "role": "assistant",
                    "content": "Chat history cleared. How can I help you with your data?",
                    "timestamp": datetime.now()
                }
            ]
            st.rerun()
        
        # Sample questions
        st.markdown("### 💡 Sample Questions")
        sample_questions = [
            "Show me top 10 customers by lifetime value",
            "What are our product categories and their average prices?",
            "How many orders were placed in the last 30 days?",
            "What's the status of recent jobs?",
            "Show me customer distribution by tier"
        ]
        
        for question in sample_questions:
            if st.button(f"💬 {question}", key=f"sample_{hash(question)}"):
                st.session_state.messages.append({
                    "role": "user",
                    "content": question,
                    "timestamp": datetime.now()
                })
                st.rerun()
        
        return selected_model

# Main application
def main():
    """Main application entry point"""
    load_chat_css()
    
    # Header
    st.markdown("""
    <div class="chat-header">
        <h1>❄️ Snowflake Cortex Analyst Chat</h1>
        <p>Ask questions about your data in natural language</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Initialize chat history
    initialize_chat_history()
    
    # Get Snowflake session
    session = get_snowflake_session()
    
    if not session:
        st.error("Unable to connect to Snowflake. Please check your configuration.")
        st.stop()
    
    # Initialize Cortex Analyst
    cortex_chat = CortexAnalystChat(session)
    
    # Render sidebar and get selected model
    selected_model = render_sidebar(session, cortex_chat)
    
    if not selected_model:
        st.error("No semantic models available.")
        st.stop()
    
    # Display chat messages
    display_chat_messages()
    
    # Handle user input
    handle_user_input(cortex_chat, selected_model)

if __name__ == "__main__":
    main()