import { useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';

export function JoinPage() {
  const { code } = useParams<{ code: string }>();
  const navigate = useNavigate();

  useEffect(() => {
    if (code) {
      navigate(`/?code=${code.toUpperCase()}`, { replace: true });
    } else {
      navigate('/', { replace: true });
    }
  }, [code, navigate]);

  return null;
}
